#!/usr/bin/env python3

from pathlib import Path
import os
import re
import resource
import runpy
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-overlay-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        (base / "Probe.qml").write_text('import QtQuick\nItem {}\n')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import "modules/animations/OverlayMotion.js" as Motion
import "modules/core"
import "modules/services"
import "modules/ui/overlay"
import "modules/ui/overlay/settings/components"

ShellRoot
{
    id: tests
    property var timings: []
    property double requested: 0
    property string pending: ""
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name)
    {
        if (item.objectName === name) return item;
        for (const child of item.children)
        {
            const found = find(child, name);
            if (found) return found;
        }
        return null;
    }
    QtObject
    {
        id: probeHost
        function activeFor(name) { return true; }
        function revealFor(name) { return 0.5; }
        function dismiss(name) {}
    }
    Component { id: viewProbe; OverlayView { host: probeHost; name: "probe" } }
    Component { id: panelProbe; OverlayPanel { width: 800; height: 500; fluid: true; shadow: false } }
    Window
    {
        id: window
        visible: true; width: 1024; height: 768
        OverlayFixture { id: overlay; anchors.fill: parent }
        SettingsPageSlot { id: slot; visible: false }
    }
    Connections
    {
        target: overlay.testPage
        function onLoaded()
        {
            if (tests.pending === "") return;
            tests.timings = tests.timings.concat([{ name: tests.pending, mode: Config.themeAnimations, milliseconds: Date.now() - tests.requested }]);
            tests.pending = "";
        }
    }
    Timer
    {
        interval: 35; repeat: true; running: true
        property int step: 0
        property int waits: 0
        property int index: 0
        property int mode: 0
        property int prepared: 0
        property double since: 0
        property Item rapidView: null
        property real reversal: 0
        readonly property var names: ["settings", "launcher", "wallpapers", "helper", "power", "desktopMenu"]
        onTriggered:
        {
            if (!Config.initialized) return;
            try
            {
                tests.check(++waits < 400, "Overlay checks did not finish");
                switch (step)
                {
                    case 0:
                        const probe = viewProbe.createObject(window.contentItem);
                        tests.check(probe.ready, "Overlay entrance waits for another event-loop turn");
                        probe.arrival = 0.5;
                        tests.check(probe.reveal === 0.5, "Host and view entrances multiply their fades");
                        Config.set("themeAnimations", 2);
                        probe.destroy();
                        const sample = panelProbe.createObject(window.contentItem, {reveal: 0});
                        tests.check(sample.surface.width === 0 && sample.surface.height === 0, "Overlay does not start at a point");
                        sample.reveal = 0.4;
                        tests.check(sample.surface.width === 320 && sample.surface.height === 320 && sample.contentItem.opacity === 0,
                            "Overlay edges do not expand at the same speed before content appears");
                        sample.reveal = 0.75;
                        tests.check(sample.surface.width === 600 && sample.surface.height === 500
                            && sample.contentItem.width === 800 && sample.contentItem.height === 500
                            && sample.contentItem.opacity > 0 && sample.contentItem.opacity < 1,
                            "The shorter edge does not finish first or content does not fade at its final layout size");
                        sample.destroy();
                        slot.enter(Qt.resolvedUrl("Probe.qml"), 0);
                        tests.check(slot.opacity === 1 && slot.shift === 0, "First settings page has an extra entrance delay");
                        slot.leave(0); Config.set("themeAnimations", 0);
                        prepared = overlay.preparedComponents.length;
                        OverlayState.show("launcher");
                        since = Date.now(); step = 1; break;
                    case 1:
                        if (Date.now() - since < 350) return;
                        tests.check(overlay.preparedComponents.length === prepared, "Background preparation ran while an overlay was active");
                        OverlayState.close(); step = 2; break;
                    case 2:
                        if (overlay.testPage.item || OverlayState.mounted !== "") return;
                        ServiceLock.locked = true;
                        prepared = overlay.preparedComponents.length;
                        since = Date.now(); step = 3; break;
                    case 3:
                        if (Date.now() - since < 350) return;
                        tests.check(overlay.preparedComponents.length === prepared, "Background preparation ran while locked");
                        ServiceLock.locked = false; step = 4; break;
                    case 4:
                        tests.check(!overlay.preparedComponents.some(component => component.status === Component.Error), "An overlay failed to prepare: " + overlay.preparedComponents.filter(component => component.status === Component.Error).map(component => component.errorString()).join("\n"));
                        if (overlay.preparedComponents.length < overlay.preparationOrder.length || overlay.preparedComponents.some(component => component.status === Component.Loading)) return;
                        tests.check(overlay.testPage.item === null && !OverlayState.active, "Preparing components created a live overlay");
                        tests.check(ServiceApplications.autostartClients.length === 0 && ServiceMedia.positionUsers === 0 && ServiceMedia.visualizerUsers === 0, "Background preparation subscribed hidden views");
                        step = 5; break;
                    case 5:
                        Config.set("themeAnimations", mode);
                        if (names[index] === "settings")
                            OverlayState.settingsPage = Registry.settings.findIndex(entry => entry.id === "appearance");
                        tests.pending = names[index]; tests.requested = Date.now();
                        OverlayState.show(names[index]);
                        step = 6; break;
                    case 6:
                        if (!overlay.testPage.item || overlay.testPage.item.name !== names[index]) return;
                        tests.check(overlay.testPage.item.ready && overlay.testPage.item.active, "Prepared overlay is not ready for input");
                        const view = overlay.testPage.item;
                        const panel = view.children.find(child => child.objectName === "centeredOverlayPanel");
                        if (panel)
                        {
                            const center = panel.mapToItem(view, panel.width / 2, panel.height / 2);
                            tests.check(Math.abs(center.x - (panel.x + panel.width / 2)) < 0.01
                                && Math.abs(center.y - (panel.y + panel.height / 2)) < 0.01, "Overlay panel drifts during its entrance: " + view.name);
                        }
                        if (view.name === "settings" && mode === 2)
                        {
                            if (view.reveal === 0) return;
                            const extent = Math.max(panel.width, panel.height) * view.reveal;
                            const center = panel.surface.mapToItem(panel, panel.surface.width / 2, panel.surface.height / 2);
                            tests.check(panel.surface.width === Math.min(panel.width, extent)
                                && panel.surface.height === Math.min(panel.height, extent) && panel.scale === 1
                                && Math.abs(center.x - panel.width / 2) < 0.01 && Math.abs(center.y - panel.height / 2) < 0.01,
                                "Settings is not growing the visible bounds around a fixed center");
                            tests.check(panel.contentItem.opacity === Motion.contentOpacity(view.reveal),
                                "Settings content does not follow the delayed fade");
                            tests.check(Math.abs(tests.find(overlay, "overlayScrim").opacity - Motion.scrimOpacity(view.reveal, true)) < 0.001,
                                "Settings backdrop fades on a separate timeline");
                            let child = tests.find(panel, "currentWallpaperPreview");
                            tests.check(child !== null, "Settings wallpaper preview is missing during its entrance");
                            for (; child && child !== panel.contentItem; child = child.parent)
                                tests.check(child.opacity === 1, "Settings content fades separately from its panel");
                        }
                        OverlayState.close(); step = 7; break;
                    case 7:
                        if (overlay.testPage.item || OverlayState.mounted !== "") return;
                        index++;
                        if (index >= names.length) { index = 0; mode++; }
                        if (mode < 3) { step = 5; break; }
                        OverlayState.show("settings"); step = 8; break;
                    case 8:
                        rapidView = overlay.testPage.item;
                        if (!rapidView || rapidView.reveal < 0.25) return;
                        tests.check(rapidView.reveal < 1, "Rapid-toggle fixture missed the opening animation");
                        reversal = rapidView.reveal;
                        OverlayState.toggle("settings");
                        tests.check(rapidView.reveal === reversal, "Closing jumped away from the current position");
                        step = 9; break;
                    case 9:
                        if (rapidView.reveal >= reversal) return;
                        tests.check(rapidView.reveal > 0, "Rapid-toggle fixture missed the closing animation");
                        reversal = rapidView.reveal;
                        OverlayState.toggle("settings");
                        tests.check(overlay.testPage.item === rapidView && rapidView.reveal === reversal,
                            "Reopening reset or replaced the moving panel");
                        step = 10; break;
                    case 10:
                        if (rapidView.reveal < 1) return;
                        tests.check(overlay.testPage.item === rapidView && OverlayState.current === "settings",
                            "A stale close unloaded the reopened overlay");
                        OverlayState.close(); step = 11; break;
                    case 11:
                        if (overlay.testPage.item || OverlayState.mounted !== "") return;
                        tests.check(ServiceApplications.autostartClients.length === 0 && ServiceMedia.positionUsers === 0 && ServiceMedia.visualizerUsers === 0, "Closing overlays retained resource subscriptions");
                        console.log("OVERLAY_TIMINGS", JSON.stringify(tests.timings));
                        console.log("OVERLAYS_PASSED centered expansion, rapid reversals, first settings page, preparation, guards and cleanup in every animation mode");
                        Qt.quit(); break;
                }
            }
            catch (error) { console.error("OVERLAYS_FAILED", step, error); Qt.quit(); }
        }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=25)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "OVERLAYS_PASSED" in output, output
        assert not re.search(r"OVERLAYS_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


def launcher_checks(preview=False):
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyShell-launcher-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        service = base / "modules/services/ServiceApplications.qml"
        source = service.read_text().replace("readonly property var applications: DesktopEntries.applications.values || []", "property var applications: []\n    property var launchLog: []")
        source = source.replace("function launchEntry(entry)\n    {", "function launchEntry(entry)\n    {\n        if (entry) launchLog = launchLog.concat([entry.id]);\n        return;")
        service.write_text(source)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/launcher"

ShellRoot {
    Window {
        id: window; visible: true; width: 800; height: 800; color: Theme.settingsColorSidebar
        QtObject {
            id: launcherHost
            function activeFor(name) { return OverlayState.current === name; }
            function revealFor(name) { return activeFor(name) ? 1 : 0; }
            function dismiss(name) { OverlayState.hide(name); }
        }
        Launcher { id: launcher; anchors.fill: parent; host: launcherHost }
        TestCase {
            id: input; when: false; optional: true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function find(item, name) {
                if (item.objectName === name) return item;
                for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
                return null;
            }
            function exercise() {
                const names = ["Calculator", "Files", "Music & <Tools>", "Terminal", "Web Browser"];
                for (let i=0; i<19; i++) names.push("Application " + String(i+1).padStart(2,"0"));
                ServiceApplications.applications = names.map((name,i)=>({id:"fixture-"+i,name:name,icon:String(Icon.settingsApplications)}));
                OverlayState.show("launcher"); wait(250);
                const content=find(launcher,"launcherContent"), search=find(content,"launcherSearchInput"), list=find(content,"launcherResults");
                for (const scenario of [{w:800,h:800,theme:1,lang:"en",motion:0},{w:400,h:430,theme:0,lang:"ru",motion:0},{w:800,h:800,theme:1,lang:"en",motion:2}]) {
                    window.width=scenario.w;window.height=scenario.h;
                    Config.set("themeStyle",scenario.theme);Config.set("shellLanguage",scenario.lang);Config.set("themeAnimations",scenario.motion);
                    OverlayState.show("launcher");search.text="";search.forceActiveFocus();wait(400);
                    const surface=find(content,"launcherResultsPanel"), label=find(list,"launcherResultName");
                    check(content.apps.length===24 && label.font.pixelSize===13 && search.font.pixelSize===14,"Launcher typography or app catalog changed");
                    const p=content.mapToItem(window.contentItem,0,0);
                    check(p.x>=0 && p.y>=0 && p.x+content.width<=window.width && p.y+content.height<=window.height,"Launcher extends outside a small screen");
                    check(list.height>0 && surface.y+surface.height<content.height && list.width<surface.width,"Result panel or footer overlaps");
                    keyClick(Qt.Key_Down);check(content.selectedID===1,"Arrow navigation failed");
                    keyClick(Qt.Key_K,Qt.ControlModifier);check(content.selectedID===0,"Control-K navigation failed");
                    content.move(23);wait(600);
                    check(content.selectedID===23 && list.contentY>0,"Last keyboard result did not scroll into view: " + JSON.stringify({selected:content.selectedID,y:list.contentY,height:list.height,contentHeight:list.contentHeight,scenario:scenario}));
                    const selected=list.currentItem;
                    check(selected.y>=list.contentY-1 && selected.y+selected.height<=list.contentY+list.height+1,"Selected result is clipped");
                    search.text="calculator";wait(400);
                    check(content.apps.length===1 && content.selectedID===0 && list.contentY===0,"Search leaves stale selection or scroll position");
                    keyClick(Qt.Key_Escape);wait(400);
                    check(search.text==="" && OverlayState.current==="launcher","Escape did not clear search before closing");
                    search.text="not-a-real-application";wait(400);
                    check(list.count===0 && list.height>0,"No-results state has invalid geometry");
                    search.text="terminal";wait(400);
                    const clear=find(content,"launcherClear");mouseClick(clear,clear.width/2,clear.height/2);wait(400);
                    check(search.text==="" && search.activeFocus,"Clear lost keyboard focus");
                    search.text="music";wait(400);
                    check(content.marked("Music & <Tools>").includes("&amp; &lt;Tools&gt;"),"Application names are not escaped");
                    keyClick(Qt.Key_Return);wait(30);
                    check(ServiceApplications.launchLog.slice(-1)[0]==="fixture-2" && OverlayState.current==="","Enter launched the wrong result or kept the launcher open");
                }
                OverlayState.show("launcher");search.text="";wait(400);
                mouseMove(window.contentItem,0,0);wait(10);
                const first=list.itemAtIndex(0);mouseMove(first,20,first.height/2);wait(20);
                const indicator=list.highlightItem, startY=indicator.y;
                const second=list.itemAtIndex(1);mouseMove(second,20,second.height/2);wait(55);
                check(content.selectedID===1,"Pointer selection is wrong inside the inset results panel");
                check(indicator.y>startY && indicator.y<second.y,"Launcher highlight snaps on mouse hover");
                wait(240);
                check(indicator.y===second.y,"Launcher highlight did not settle on the hovered result");
                mouseClick(second,20,second.height/2);wait(30);
                check(ServiceApplications.launchLog.slice(-1)[0]===content.apps[1].id,"Pointer click launched the wrong application");
                if (PREVIEW) {
                    OverlayState.show("launcher");search.text="";Config.set("themeAnimations",0);wait(100);
                    content.grabToImage(result=>{result.saveToFile("/tmp/bloodyShell-launcher-dark.png");});wait(100);
                    Config.set("themeStyle",0);Config.set("shellLanguage","ru");window.width=400;window.height=430;wait(100);
                    content.grabToImage(result=>{result.saveToFile("/tmp/bloodyShell-launcher-light.png");});wait(100);
                }
                console.log("LAUNCHER_PASSED themes, localization, small screens, keyboard/pointer launch, filtering, scrolling, clear and empty results");Qt.quit();
            }
        }
        Timer {interval:150;running:Config.initialized;onTriggered:{try{input.exercise();}catch(error){console.error("LAUNCHER_FAILED",error);Qt.quit();}}}
    }
}
'''.replace("PREVIEW", "true" if preview else "false"))
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=16)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "LAUNCHER_PASSED" in output, output
        assert not re.search(r"LAUNCHER_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


def desktop_menu_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-desktop-menu-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay"

ShellRoot {
    Window {
        id: window; width:800; height:600; visible:true
        OverlayFixture { id:overlay; anchors.fill:parent }
        TestCase {
            id:events; name:"DesktopMenu"; when:false; optional:true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function until(predicate, message) {
                for (let i=0; i<100 && !predicate(); i++) wait(10);
                check(predicate(), message);
            }
            function openAt(point) {
                OverlayState.showDesktopMenu(Quickshell.screens[0].name,point.x,point.y);
                until(()=>overlay.testPage.item && overlay.testPage.item.name === "desktopMenu", "Menu did not load");
                return overlay.testPage.item;
            }
            function closed() { until(()=>!overlay.testPage.item && !OverlayState.active, "Menu did not finish closing"); }
            function exercise() {
                window.requestActivate();
                ServiceCompositor.backend.runningVersion = "niri 26.04";
                Config.set("shellSurface", Enums.SurfaceBlur);
                check(ShellMaterial.blur, "Blur fixture did not enable compositor blur");
                for (const mode of [0,1,2]) {
                    Config.set("themeAnimations",mode);
                    for (const point of [Qt.point(20,20),Qt.point(780,20),Qt.point(20,580),Qt.point(780,580)]) {
                        const menu = openAt(point), card = findChild(menu,"desktopMenuCard");
                        wait(25);
                        check(card && menu.selected === -1, "Opening retained the previous selection");
                        if (mode === 0) check(card.amount === 1 && card.revealWidth === card.width && card.revealHeight === card.height, "Disabled animations still animate");
                        else check(card.amount > 0 && card.amount < 1 && card.revealWidth < card.width && card.revealHeight < card.height, "Context menu does not expand in both dimensions");
                        const fill = card.surface.materialSurface;
                        const bounds = fill.mapToItem(window.contentItem, 0, 0, fill.width, fill.height);
                        check(card.opacity === 1 && fill.blurActive && fill.blurMask.x === Math.round(bounds.x)
                            && fill.blurMask.y === Math.round(bounds.y) && fill.blurMask.width > 0 && fill.blurMask.height > 0
                            && fill.width === card.revealWidth && fill.height === card.revealHeight, "Menu blur does not match the growing surface");
                        const left = card.mapToItem(window.contentItem,0,0), right = card.mapToItem(window.contentItem,card.width,card.height);
                        check(left.x >= 8 && left.y >= 8 && right.x <= window.width-8 && right.y <= window.height-8, "Animation moves the menu beyond a screen edge");
                        check(card.anchorX === Math.max(0,Math.min(1,(point.x-card.x)/card.width)) && card.anchorY === Math.max(0,Math.min(1,(point.y-card.y)/card.height)), "Menu expands from the wrong origin");
                        const anchor = card.mapToItem(window.contentItem, card.width*card.anchorX, card.height*card.anchorY);
                        const shownAnchor = card.surface.mapToItem(window.contentItem, card.revealWidth*card.anchorX, card.revealHeight*card.anchorY);
                        check(Math.abs(anchor.x-shownAnchor.x)<0.01 && Math.abs(anchor.y-shownAnchor.y)<0.01,"Expansion moves its pointer anchor");
                        until(()=>card.amount === 1, "Entrance did not settle");
                        keyClick(Qt.Key_Down); check(menu.selected === 0, "Menu did not receive keyboard focus");
                        keyClick(Qt.Key_Escape);
                        if (mode !== 0) {
                            wait(25);
                            check(card.opacity === 1 && card.amount > 0 && card.amount < 1 && fill.blurActive
                                && fill.width < card.width && fill.height < card.height, "Menu blur does not match the shrinking surface");
                        }
                        closed();
                        check(ShellMaterial.regionsFor(window).length === 0, "Closed menu retained its blur region");
                    }
                    const menu = openAt(Qt.point(300,200));
                    until(()=>menu.reveal === 1, "Menu did not open before interruption");
                    keyClick(Qt.Key_Down); keyClick(Qt.Key_Down);
                    OverlayState.close();
                    if (mode !== 0) wait(30);
                    const reopened = openAt(Qt.point(600,400));
                    check(reopened.selected === -1, "Reopening did not reset keyboard selection");
                    const card = findChild(reopened,"desktopMenuCard");
                    until(()=>card.amount === 1, "Interrupted exit did not reopen");
                    mouseClick(window.contentItem,2,2,Qt.RightButton,Qt.NoModifier,0);
                    closed();
                }
                Config.set("themeAnimations",2);
                const menu = openAt(Qt.point(300,200)); wait(25);
                Config.set("themeAnimations",0);
                check(findChild(menu,"desktopMenuCard").amount === 1, "Disabling animations leaves a partial reveal");
                keyClick(Qt.Key_Down); keyClick(Qt.Key_Down); keyClick(Qt.Key_Return);
                until(()=>overlay.testPage.item && overlay.testPage.item.name === "settings", "Keyboard action did not open settings");
                OverlayState.close(); closed();

                for (const mode of [1,2]) {
                    Config.set("themeAnimations", mode);
                    OverlayState.show("settings");
                    const settings = overlay.testPage.item;
                    const panel = findChild(settings, "centeredOverlayPanel");
                    const sidebar = findChild(settings, "settingsSidebar");
                    const fill = findChild(panel.surfaceLayer, "settingsSidebarSurface");
                    until(()=>fill.blurActive, "Settings sidebar did not acquire blur");
                    check(panel.partiallyRevealed && fill.width < sidebar.width && fill.opacity === 1,
                        "Settings sidebar waits until the overlay has opened to show its surface");
                    check(settings.scrimCutout === fill && ShellMaterial.regionsFor(window).includes(fill.blurMask),
                        "Settings sidebar tint, scrim opening and blur use different surfaces");
                    until(()=>settings.reveal === 1, "Settings did not finish opening");
                    check(fill.width === sidebar.width && fill.height === sidebar.height,
                        "Sidebar surface did not reach its full size");
                    OverlayState.close();
                    until(()=>fill.width < sidebar.width && fill.blurActive, "Settings sidebar blur did not shrink on close");
                    closed();
                    check(ShellMaterial.regionsFor(window).length === 0, "Settings left a blur region behind");
                }

                Config.set("themeAnimations", 0);
                const staticMenu = openAt(Qt.point(80,120));
                const staticCard = findChild(staticMenu, "desktopMenuCard");
                const mask = staticCard.surface.materialSurface.blurMask;
                const originalWidth = mask.width;
                const originalX = mask.x;
                OverlayState.origin = Qt.point(280,120);
                check(mask.width === originalWidth && mask.x === originalX + 200,
                    "Moving only a menu ancestor left the blur mask at its previous position");
                until(()=>!overlay.refreshBlurOnFrame, "Blur refresh did not run after the backing window started rendering");
                OverlayState.close(); closed();

                OverlayState.show("launcher");
                let panel = findChild(overlay.testPage.item, "centeredOverlayPanel");
                let fill = panel.blurSurface;
                check(fill && ShellMaterial.regionsFor(window).includes(fill.blurMask) && fill.color.a === 1,
                    "First launcher frame exposed the background before its blur mask was active");
                until(()=>fill.color.a < 1, "Launcher did not switch from its first-frame tint to blur");
                OverlayState.close(); closed();

                Config.set("themeAnimations", 1);
                Config.set("wallpaperCurrent", String(Qt.resolvedUrl("fixture.png")).slice(7));
                Config.set("shellSurface", Enums.SurfaceBackdrop);
                const warmTexture = findChild(overlay, "shellWallpaperTexture");
                until(()=>warmTexture?.status === Image.Ready, "Overlay did not warm the Backdrop sample");
                OverlayState.show("launcher");
                panel = findChild(overlay.testPage.item, "centeredOverlayPanel");
                until(()=>panel.reveal > 0, "Backdrop launcher did not start opening");
                check(panel.opacity === 1 && panel.partiallyRevealed,
                    "Backdrop launcher exposed the background with a transparent surface fade");
                OverlayState.close(); closed();

                console.log("DESKTOP_MENU_PASSED geometry, input, rapid reopen, blur cleanup, and stable first frames");
                Qt.quit();
            }
        }
        Timer { interval:100; running:Config.initialized; onTriggered:{ try { events.exercise(); } catch(error) { console.error("DESKTOP_MENU_FAILED",error); Qt.quit(); } } }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "DESKTOP_MENU_PASSED" in output, output
        assert not re.search(r"DESKTOP_MENU_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output


def wallpaper_dismiss_checks():
    import json
    import shutil

    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-wallpaper-dismiss-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        (base / "wallpapers").mkdir()
        for index in range(9):
            shutil.copyfile(base / "fixture.png", base / "wallpapers" / f"{index}.png")
        current = str(base / "wallpapers/4.png")
        (base / "config/bloodyShell/settings.json").write_text(json.dumps(dict(helperSeen=True,
            themeAnimations=0, wallpaperDirectory=str(base / "wallpapers"), wallpaperCurrent=current)))
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/ui/overlay"

ShellRoot {
    Window {
        id:window; width:900; height:650; visible:true
        OverlayFixture { id:overlay; anchors.fill:parent }
        TestCase {
            id:events; name:"WallpaperDismiss"; when:false; optional:true
            function check(ok,message) { if(!ok) throw new Error(message); }
            function until(predicate,message) { for(let i=0;i<200 && !predicate();i++) wait(10); check(predicate(),message); }
            function picker() { return overlay.testPage.item ? findChild(overlay.testPage.item,"wallpapersContent") : null; }
            function open() {
                OverlayState.show("wallpapers");
                until(()=>picker() && !picker().loading && picker().images.length===9 && picker().galleryReveal===1,"Wallpaper picker did not open");
                return picker();
            }
            function closed() { until(()=>!OverlayState.active && !overlay.testPage.item,"Empty-space click did not dismiss the overlay"); }
            function exercise() {
                const initial=Config.wallpaperCurrent;
                for(const mode of [0,1,2]) {
                    Config.set("themeAnimations",mode);
                    if (mode===2) {
                        OverlayState.show("wallpapers");
                        until(()=>picker() && picker().reveal>0,"Wallpaper picker did not start opening");
                        check(picker().reveal<0.9,"Dismiss fixture missed the opening transition");
                        mouseClick(window.contentItem,4,4,Qt.RightButton,Qt.NoModifier,0); closed();
                    }
                    let content=open();
                    if (mode===2) {
                        const view=overlay.testPage.item;
                        const center=findChild(content,"wallpaperCard-4"), inner=findChild(content,"wallpaperCard-5"), outer=findChild(content,"wallpaperCard-6");
                        const caption=findChild(content,"wallpaperCaptionBackground"), finalY=center.y, captionY=caption.y;
                        content.reveal=0.12;
                        check(center.y>finalY && center.opacity>0 && inner.opacity===0 && outer.opacity===0,
                            "Fluid picker did not start with only the center card");
                        content.reveal=0.30;
                        check(inner.y>finalY && inner.opacity>0 && outer.opacity===0 && caption.opacity===0,
                            "Inner cards did not rise before the outer cards");
                        content.reveal=0.75;
                        check(outer.y>finalY && outer.opacity>0 && caption.opacity>0 && caption.y>captionY,
                            "Outer cards and controls did not rise into view");
                        content.reveal=Qt.binding(()=>view.reveal);
                        check(center.y===finalY && inner.y===finalY && outer.y===finalY && caption.opacity===1,
                            "Fluid picker did not settle into its final layout");
                    }
                    mouseClick(window.contentItem,4,4,Qt.LeftButton,Qt.NoModifier,0); closed();
                    content=open();
                    mouseClick(window.contentItem,window.width-4,window.height-4,Qt.RightButton,Qt.NoModifier,0); closed();
                    content=open();
                    const next=findChild(content,"wallpaperNext");
                    mouseClick(next,next.width/2,next.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    check(OverlayState.current==="wallpapers" && content.index===5,"Navigation also dismisses the picker");
                    wait(Theme.animationDurationMorph+40);
                    const side=findChild(content,"wallpaperCard-6");
                    mouseClick(side,side.width*0.85,side.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    check(OverlayState.current==="wallpapers" && content.index===6,"Side preview selection also dismisses the picker");
                    mousePress(window.contentItem,450,30,Qt.LeftButton,Qt.NoModifier,0);
                    mouseMove(window.contentItem,430,30,0);
                    mouseMove(window.contentItem,330,30,0);
                    mouseRelease(window.contentItem,330,30,Qt.LeftButton,Qt.NoModifier,0);
                    check(OverlayState.current==="wallpapers" && !content.dragging,"Dragging through empty space dismisses the picker");
                    mouseClick(window.contentItem,450,30,Qt.LeftButton,Qt.NoModifier,0); closed();
                    check(Config.wallpaperCurrent===initial,"Empty-space interaction changed the wallpaper");
                }
                console.log("WALLPAPER_DISMISS_PASSED left/right empty-space taps, drag cancellation, arrows and side previews in every animation mode");
                Qt.quit();
            }
        }
        Timer { interval:100; running:Config.initialized; onTriggered:{ try { events.exercise(); } catch(error) { console.error("WALLPAPER_DISMISS_FAILED",error); Qt.quit(); } } }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "WALLPAPER_DISMISS_PASSED" in output, output
        assert not re.search(r"WALLPAPER_DISMISS_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output


def wallpaper_stack_checks():
    import json
    import shutil

    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-wallpaper-stack-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        (base / "home").mkdir()
        env["HOME"] = str(base / "home")
        (base / "wallpapers").mkdir()
        for index in range(6):
            shutil.copyfile(base / "fixture.png", base / "wallpapers" / f"{index}.png")
        (base / "wallpaper-deny").write_text("no")
        (base / "bin/awww").write_text('''#!/usr/bin/env python3
import os, sys
from pathlib import Path
if (Path(os.environ["TEST_SCREENSHOT_BASE"]) / "wallpaper-deny").read_text() == "yes":
    print("Fixture wallpaper failure", file=sys.stderr)
    sys.exit(1)
''')
        (base / "modules/services/ServiceGreeter.qml").write_text('pragma Singleton\nimport Quickshell\nSingleton { signal wallpaperApplied() }\n')
        (base / "config/bloodyShell/settings.json").write_text(json.dumps(dict(helperSeen=True,
            themeAnimations=0, wallpaperDirectory=str(base / "wallpapers"), wallpaperCurrent=str(base / "wallpapers/0.png"))))
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "modules/core"
import "modules/services"
import "modules/ui/overlay"
import "modules/ui/overlay/settings/components"

ShellRoot {
    FileView { id: deny; path: Quickshell.env("TEST_SCREENSHOT_BASE") + "/wallpaper-deny"; blockWrites: true }
    Window {
        id: window; width:1024; height:768; visible:true
        OverlayFixture { id: overlay; anchors.fill:parent }
        SettingsPopup { id: dialog; host:window.contentItem; width:240; height:120; contentItem:TextInput { text:"Retained popup" } }
        TestCase {
            id: events; when:false; optional:true
            function check(ok,message) { if(!ok) throw new Error(message); }
            function until(predicate,message) { for(let i=0;i<300 && !predicate();i++) wait(10); check(predicate(),message); }
            function stacked() { return findChild(overlay,"stackedOverlayPage"); }
            function picker() { return stacked().item ? findChild(stacked().item,"wallpapersContent") : null; }
            function openPicker() {
                OverlayState.show("wallpapers");
                until(()=>picker() && !picker().loading && picker().images.length===6 && overlay.stackedReveal===1,"Stacked picker did not open");
                check(OverlayState.current==="wallpapers" && overlay.currentView===stacked().item && !overlay.testPage.enabled && stacked().enabled,"Picker did not own input");
                return picker();
            }
            function returned(original,page,scroll) {
                until(()=>OverlayState.stacked==="" && !stacked().item && overlay.testPage.enabled,"Picker did not finish returning to settings");
                check(OverlayState.current==="settings" && overlay.testPage.item===original && overlay.currentView===original,"Settings was recreated or closed");
                check(Math.abs(page.contentY-scroll)<0.01 && Registry.settings[OverlayState.settingsPage].id==="appearance","Settings lost its page or scroll position");
                wait(20);
            }
            function closed() { until(()=>!OverlayState.active && !overlay.testPage.item && !stacked().item,"Closing retained an overlay layer"); }
            function exercise() {
                OverlayState.settingsPage=Registry.settings.findIndex(page=>page.id==="appearance");
                for(const mode of [0,1,2]) {
                    Config.set("themeAnimations",mode);
                    OverlayState.show("settings");
                    until(()=>overlay.testPage.item && findChild(overlay.testPage.item,"currentWallpaperPreview"),"Appearance did not load");
                    const original=overlay.testPage.item;
                    const preview=findChild(original,"currentWallpaperPreview");
                    const selector=findChild(original,"wallpaperTransitionSelector");
                    let page=selector.parent;
                    while(page && typeof page.resetScroll!=="function") page=page.parent;
                    check(page && page.contentHeight>page.height,"Appearance cannot exercise scroll preservation");
                    page.contentY=Math.min(180,page.contentHeight-page.height);
                    const scroll=page.contentY;
                    selector.forceActiveFocus();
                    const focus=window.activeFocusItem;
                    overlay.output="held-output";
                    ServiceCompositor.backend.focusedOutput="other-output";
                    preview.clicked();
                    until(()=>picker() && !picker().loading && overlay.stackedReveal===1,"Preview did not open wallpapers above settings");
                    check(overlay.testPage.item===original && overlay.output==="held-output" && !overlay.testPage.enabled,"Opening the picker replaced settings, moved outputs or retained input");
                    if(mode!==0) {
                        const reopening=stacked().item;
                        OverlayState.hide("wallpapers"); wait(20);
                        OverlayState.show("wallpapers");
                        until(()=>overlay.stackedReveal===1,"Interrupted close did not reopen the picker");
                        check(stacked().item===reopening && overlay.testPage.item===original,"Reopening recreated an overlay layer");
                    }
                    keyClick(Qt.Key_Escape);
                    OverlayState.show("settings");
                    returned(original,page,scroll);
                    check(overlay.output==="held-output" && window.activeFocusItem===focus,"Returning moved outputs or lost keyboard focus");

                    const content=openPicker();
                    content.select((content.index+1)%content.images.length);
                    const selected=content.selectedPath;
                    deny.setText("yes"); deny.waitForJob();
                    content.apply(content.index);
                    until(()=>!ServiceAppearance.wallpaperBusy && ServiceAppearance.wallpaperError!=="","Failed wallpaper did not report its error");
                    check(OverlayState.current==="wallpapers" && overlay.testPage.item===original,"Failed apply dismissed the picker or settings");
                    deny.setText("no"); deny.waitForJob();
                    content.apply(content.index);
                    until(()=>OverlayState.current==="settings","Applying did not return to settings");
                    returned(original,page,scroll);
                    check(Config.wallpaperCurrent===selected,"Applying did not save the wallpaper");

                    dialog.open(); until(()=>dialog.opened,"Popup did not open");
                    openPicker();
                    check(dialog.presenting && dialog.suspended && dialog.opacity===0 && !dialog.modal,"A background popup covers the picker");
                    if(mode===1) {
                        overlay.takeScreenshot();
                        until(()=>ServiceScreenshot.phase==="ready","Screenshot did not open over both layers");
                        check(OverlayState.current==="wallpapers" && overlay.testPage.item===original && !stacked().enabled,"Screenshot replaced layers or retained picker input");
                        keyClick(Qt.Key_Escape);
                        until(()=>ServiceScreenshot.phase==="idle","Screenshot did not close");
                        check(OverlayState.current==="wallpapers" && dialog.suspended,"Closing screenshot dismissed the picker or restored its background popup");
                    }
                    mouseClick(window.contentItem,4,4,Qt.LeftButton,Qt.NoModifier,0);
                    returned(original,page,scroll);
                    check(dialog.visible && dialog.modal && !dialog.suspended,"Returning did not restore the existing popup");
                    dialog.close(); until(()=>!OverlayState.settingsPopup,"Popup did not close");
                    openPicker();
                    ServiceCompositor.backend.focusedWorkspaceId=mode+100;
                    closed();
                }
                Config.set("themeAnimations",0);
                for(const name of ["launcher","helper","power","desktopMenu"]) {
                    OverlayState.show(name);
                    until(()=>overlay.testPage.item && overlay.testPage.item.name===name,"Parent overlay did not load");
                    const original=overlay.testPage.item;
                    openPicker();
                    OverlayState.hide("wallpapers");
                    until(()=>!stacked().item,"Picker did not close above another overlay");
                    check(OverlayState.current===name && overlay.testPage.item===original,"Picker did not restore its parent overlay");
                    OverlayState.close(); closed();
                }
                OverlayState.show("settings"); openPicker();
                OverlayState.show("launcher");
                check(OverlayState.current==="launcher" && OverlayState.stacked==="" && overlay.testPage.item.name==="launcher","Switching overlays retained a stale layer");
                OverlayState.close(); closed();
                OverlayState.show("settings"); openPicker();
                ServiceLock.locked=true; closed();
                ServiceLock.locked=false;
                check(!OverlayState.active,"Unlocking resurrected covered settings");
                console.log("WALLPAPER_STACK_PASSED preserved views/pages/scroll/focus/output, apply/retry, popup and screenshot order, workspace/lock cleanup, replacements and every animation mode");
                Qt.quit();
            }
        }
        Timer { interval:120; running:Config.initialized; onTriggered:{ try { events.exercise(); } catch(error) { console.error("WALLPAPER_STACK_FAILED",error); Qt.quit(); } } }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=35)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "WALLPAPER_STACK_PASSED" in output, output
        assert not re.search(r"WALLPAPER_STACK_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output


def wayland_checks():
    display = os.environ.get("WAYLAND_DISPLAY")
    if not display:
        print("SKIP native overlay check: a Wayland session with two outputs is required")
        return
    socket = str(Path(os.environ["XDG_RUNTIME_DIR"]) / display)
    source = (ROOT / "modules/ui/overlay/Overlay.qml").read_text()
    inhibitor = next(line.strip() for line in source.splitlines() if line.strip().startswith("ShortcutInhibitor {"))
    inhibitor = inhibitor.replace("ShortcutInhibitor {", "ShortcutInhibitor { id: shortcuts;", 1)
    with tempfile.TemporaryDirectory(prefix="bloodyshell-overlay-wayland-") as temporary:
        base = Path(temporary)
        for name in ("runtime", "cache", "config", "home"):
            (base / name).mkdir(mode=0o700)
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: tests
    property int phase: 0
    property int round: 0
    property int ticks: 0
    function check(ok, message) { if (!ok) throw new Error(message); }
    PanelWindow {
        id: overlay
        property bool modal: true
        // The test never takes focus or pointer input from the user's applications.
        implicitWidth: 8; implicitHeight: 8
        visible: false; color: "transparent"
        anchors { top: true; left: true }
        screen: Quickshell.screens[0]
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "bloodyShell:test-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        INHIBITOR
    }
    Timer {
        interval: 80; repeat: true; running: true
        onTriggered: {
            try {
                tests.check(Quickshell.screens.length >= 2, "Two connected Wayland outputs are required");
                tests.check(++tests.ticks < 160, "Native surface check timed out");
                switch (tests.phase) {
                    case 0:
                        tests.check(!shortcuts.enabled, "Hidden surface retained its shortcut inhibitor");
                        overlay.screen = Quickshell.screens[tests.round % Quickshell.screens.length];
                        overlay.visible = true; tests.phase = 1; break;
                    case 1:
                        if (!overlay.backingWindowVisible) return;
                        tests.check(shortcuts.enabled, "Visible modal surface lost shortcut inhibition");
                        overlay.screen = Quickshell.screens[(tests.round + 1) % Quickshell.screens.length];
                        tests.phase = 2; break;
                    case 2:
                        if (!overlay.backingWindowVisible) return;
                        tests.check(shortcuts.enabled, "Moving the surface did not restore shortcut inhibition");
                        overlay.modal = false;
                        tests.check(!shortcuts.enabled, "Closing the modal retained shortcut inhibition");
                        overlay.modal = true;
                        overlay.visible = false; tests.phase = 3; break;
                    case 3:
                        tests.check(!overlay.backingWindowVisible && !shortcuts.enabled, "Destroying the surface retained its inhibitor");
                        if (++tests.round < Quickshell.screens.length * 6) { tests.phase = 0; break; }
                        console.log("OVERLAY_WAYLAND_PASSED", tests.round, "hidden/visible moves, native surface recreation and inhibitor cleanup");
                        Qt.quit(); break;
                }
            } catch (error) { console.error("OVERLAY_WAYLAND_FAILED", tests.phase, error); Qt.quit(); }
        }
    }
}
'''.replace("INHIBITOR", inhibitor))
        env = dict(os.environ, QT_QPA_PLATFORM="wayland", WAYLAND_DISPLAY=socket, QS_DISABLE_CRASH_HANDLER="1",
                   HOME=str(base / "home"), XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"),
                   XDG_CONFIG_HOME=str(base / "config"), DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-session-bus")
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True,
                                timeout=18, preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_CORE, (0, 0)))
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "OVERLAY_WAYLAND_PASSED" in output, output
        assert not re.search(r"OVERLAY_WAYLAND_FAILED|FATAL|ReferenceError|TypeError|Binding loop|Failed to load configuration", output), output


if __name__ == "__main__":
    if "--wayland" in sys.argv:
        wayland_checks()
    else:
        launcher_checks()
        checks()
        desktop_menu_checks()
        wallpaper_dismiss_checks()
        wallpaper_stack_checks()
