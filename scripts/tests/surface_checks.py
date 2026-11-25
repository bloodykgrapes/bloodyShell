#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def check_sources():
    hosts = [str(path.relative_to(ROOT)) for path in ROOT.glob("modules/**/*.qml")
             if re.search(r"\bPanelWindow\s*\{", path.read_text())]
    assert sorted(hosts) == ["modules/ui/desktop/Desktop.qml", "modules/ui/desktop/OverviewBackdrop.qml",
                            "modules/ui/keyboard/VirtualKeyboard.qml", "modules/ui/layout/Layout.qml", "modules/ui/overlay/Overlay.qml"], hosts


def run_fixture(base, scenario=None):
    shutil.copytree(ROOT / "modules", base / "modules")
    (base / "assets").symlink_to(ROOT / "assets", target_is_directory=True)
    (base / "translations").symlink_to(ROOT / "translations", target_is_directory=True)
    shutil.copytree(ROOT / "scripts", base / "scripts", ignore=shutil.ignore_patterns("tests", "tools", "__pycache__"))
    (base / "scripts/lib/resources.py").write_text('''import json, sys, time
time.sleep(0.08)
if sys.argv[1:] == ["status"]:
    print(json.dumps(dict(source="repository",terminal=[],entries=[
        dict(id="compositor",available=True,kind="compositor",name="niri",destination="/tmp/fixture-niri"),
        dict(id="dots",available=True,kind="dots",name="dots",programs=["fixture"],destination="/tmp/fixture-config"),
        dict(id="greeter",available=True,kind="greeter",name="greeter",destination="/tmp/fixture-greeter"),
        dict(id="wallpapers",available=True,kind="wallpapers",name="wallpapers",destination="/tmp/fixture-wallpapers"),
    ])))
elif sys.argv[1:] == ["import", "wallpapers"]:
    print(json.dumps(dict(destination="/tmp/fixture-wallpapers",settings={})))
else:
    sys.exit(1)
''')
    fixture_module = base / "scripts/lib/resources.py"
    fixture_module.write_text("def resources_main():\n" + "".join("    " + line for line in fixture_module.read_text().splitlines(keepends=True)))
    shutil.copy2(ROOT / "version", base / "version")
    for name in ("config", "cache", "runtime", "bin"):
        (base / name).mkdir(mode=0o700)
    (base / "config/bloodyShell").mkdir()
    (base / "config/bloodyShell/settings.json").write_text(json.dumps({
        "helperSeen": True, "themeAnimations": 0, "dockPinned": ["surface-test.desktop"],
        "barType": 0, "dockType": 0, "dockHideAuto": False
    }))
    for name in ("niri", "awww", "cava"):
        path = base / "bin" / name
        path.write_text("#!/bin/sh\nexit 1\n")
        path.chmod(0o700)
    (base / "modules/services/ServiceLock.qml").write_text("pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property bool locked: false; function lock() {} }")
    (base / "modules/ui/overlay/altTab/AltTabKeyboard.qml").write_text("import QtQuick\nItem { property var targetWindow }")
    media = base / "modules/services/ServiceMedia.qml"
    media.write_text(media.read_text().replace("readonly property var players: Mpris.players.values", "property var players: []"))
    source = (base / "modules/ui/overlay/Overlay.qml").read_text().replace("PanelWindow\n{", "Item\n{\n    property Item contentItem: parent", 1)
    source = source.replace("    screen: Quickshell", "    property var screen: Quickshell")
    source = source.replace("    mask: authenticating", "    property var mask: authenticating")
    source = re.sub(r"^    (?:WlrLayershell\.|BackgroundEffect\.|exclusionMode:|exclusiveZone:).*\n", "", source, flags=re.M)
    source = source.replace('    color: "transparent"\n', "")
    source = source.replace("    anchors { top: true; bottom: true; left: true; right: true }\n", "")
    source = re.sub(r"^    ShortcutInhibitor .*\n", "", source, flags=re.M)
    source = source.replace("PolkitAgent { id: authAgent }", "QtObject { id: authAgent; property bool isActive: false; property var flow: null }")
    source = source.replace("    property string output:", "    readonly property alias testAgent: authAgent\n    readonly property alias testPage: page\n    property string output:")
    (base / "modules/ui/overlay/OverlayFixture.qml").write_text(source)
    layout = (base / "modules/ui/layout/Layout.qml").read_text()
    layout = layout.replace('import "../frame"', 'import "../frame"\nimport "." as Fixtures')
    layout = layout.replace("component Surface: PanelWindow", "component Surface: Fixtures.FakePanelWindow")
    layout = layout.replace("anchors.top:", "reserveAnchors.top:").replace("anchors.bottom:", "reserveAnchors.bottom:")
    layout = layout.replace("anchors.left:", "reserveAnchors.left:").replace("anchors.right:", "reserveAnchors.right:")
    layout = layout.replace("WlrLayershell.layer:", "surfaceLayer:")
    layout = re.sub(r"^        WlrLayershell.keyboardFocus:[^\n]*\n(?: +:[^\n]*\n)*", "", layout, flags=re.M)
    layout = re.sub(r"^        (?:WlrLayershell\.|BackgroundEffect\.).*\n", "", layout, flags=re.M)
    (base / "modules/ui/layout/LayoutFixture.qml").write_text(layout)
    (base / "modules/ui/layout/FakePanelWindow.qml").write_text('''import QtQuick
import Quickshell
Item
{
    property var screen
    property int surfaceLayer: -1
    property color color: "transparent"
    property int exclusionMode: ExclusionMode.Auto
    property int exclusiveZone: -999
    property var mask
    component EdgeAnchors: QtObject { property bool top: false; property bool bottom: false; property bool left: false; property bool right: false }
    property EdgeAnchors reserveAnchors: EdgeAnchors {}
    component EdgeMargins: QtObject { property int top: 0; property int bottom: 0; property int left: 0; property int right: 0 }
    property EdgeMargins margins: EdgeMargins {}
    width: reserveAnchors.left && reserveAnchors.right ? (screen ? screen.width : 1280) : implicitWidth
    height: reserveAnchors.top && reserveAnchors.bottom ? (screen ? screen.height : 800) : implicitHeight
    onExclusiveZoneChanged: exclusionMode = ExclusionMode.Normal
}
''')
    (base / "shell.qml").write_text(r'''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/common"
import "modules/core"
import "modules/services"
import "modules/ui/frame"
import "modules/ui/layout"
import "modules/ui/overlay"
import "modules/ui/sidebars/components"

ShellRoot
{
    id: tests
    property var savedPage: null
    property int cancellations: 0
    property int settling: 0
    property var mediaWidget: null
    property var mediaOwner: null
    property real slideBefore: 0
    property string frameBeforeSidebar: ""
    function barShape()
    {
        const surface = frame.surface;
        return JSON.stringify([surface.startBody, surface.endBody, surface.thickness, surface.cornerRadius, surface.bodyRadius, surface.smoothing]);
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function verifyMediaCenter()
    {
        const menu = loadedPage(frame.island, Qt.resolvedUrl("modules/ui/bar/menus/MenuMedia.qml"));
        check(menu, "Media menu did not load");
        const center = menu.mapToItem(frame, menu.width / 2, menu.height / 2);
        const body = frame.island.bodyRect;
        check(Math.abs(center.x - body.x - body.width / 2) <= 1, "Media menu is off center after island width changed");
    }
    function ready(name)
    {
        check(overlay.currentView !== null && overlay.currentView.name === name, "Could not load " + name);
    }
    function island(item)
    {
        if (item.isIsland) return item;
        for (const child of item.children || [])
        {
            const found = island(child);
            if (found) return found;
        }
        return null;
    }
    function find(item, name)
    {
        if (item.objectName === name) return item;
        return events.findChild(item, name);
    }
    function slot(item, name)
    {
        if (item.widgetID === name) return item;
        for (const child of item.children || []) { const found = slot(child, name); if (found) return found; }
        return null;
    }
    function dockItem(item)
    {
        if (item.windowsJson !== undefined && item.host === frame.dock) return item;
        for (const child of item.children || []) { const found = dockItem(child); if (found) return found; }
        return null;
    }
    function findAll(item, name)
    {
        const result = item.objectName === name ? [item] : [];
        for (const child of item.children || []) result.push(...findAll(child, name));
        return result;
    }
    function loadedPage(item, source)
    {
        if (String(item.source) === String(source) && item.status === Loader.Ready && item.item) return item.item;
        for (const child of item.children || []) { const found = loadedPage(child, source); if (found) return found; }
        return null;
    }
    function visibleMenuText(item)
    {
        if (item.label && item.visible && item.width > 0 && item.height > 0)
        {
            let visible = true;
            for (let node = item; node; node = node.parent)
            {
                const point = item.mapToItem(node, item.width / 2, item.height / 2);
                if (node.opacity <= 0 || (node.clip && (point.x < 0 || point.y < 0 || point.x >= node.width || point.y >= node.height))) visible = false;
            }
            const point = item.mapToItem(frame, item.width / 2, item.height / 2);
            if (visible && point.x >= 0 && point.y >= 0 && point.x < frame.width && point.y < frame.height) return true;
        }
        return (item.children || []).some(child => visibleMenuText(child));
    }
    function menuEdges()
    {
        const names = ["Battery", "Bluetooth", "Clock", "Layout", "Media", "Network", "Tray", "Volume"];
        for (const edge of [Enums.EdgeBottom, Enums.EdgeRight, Enums.EdgeTop, Enums.EdgeLeft])
        {
            Config.set("barSide", edge);
            events.wait(40);
            const trigger = slot(frame.bar, "clock").widget;
            for (const name of names)
            {
                const source = Qt.resolvedUrl("modules/ui/bar/menus/Menu" + name + ".qml");
                MenuState.toggle(source, trigger);
                events.wait(40);
                const menu = loadedPage(frame.bar, source);
                check(menu && menu.visible && menu.active && menu.presented && menu.width > 0 && menu.height > 0, "Menu is hidden on edge " + edge + ": " + name);
                if (edge === Enums.EdgeLeft || edge === Enums.EdgeRight)
                {
                    const panel = MenuState.menuOwner.panel;
                    check(Math.abs(panel.width - menu.width) < 0.01 && Math.abs(panel.height - menu.height) < 0.01, "Vertical menu background does not fit its content: " + name);
                }
                if (name !== "Layout") check(visibleMenuText(menu), "Menu content is clipped on edge " + edge + ": " + name);
                if (name === "Clock")
                {
                    menu.offset = 1;
                    const today = find(menu, "calendarToday");
                    events.mouseClick(today, today.width / 2, today.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    check(menu.offset === 0, "Menu content cannot receive clicks on edge " + edge);
                }
            }
        }
        MenuState.close();
        Config.set("barSide", Enums.EdgeTop);
        events.wait(360);
    }
    function sidebarEdges()
    {
        for (const mode of [Enums.AnimationsStandard, Enums.AnimationsFluid])
        {
            Config.set("themeAnimations", mode);
            for (const edge of [Enums.EdgeLeft, Enums.EdgeRight])
            {
                Config.set("barSide", edge);
                for (const side of ["left", "right"])
                {
                    const sidebar = side === "left" ? frame.leftSidebar : frame.rightSidebar;
                    SidebarState.toggle(side, Quickshell.screens[0].name);
                    events.wait(70);
                    const panel = sidebar.panel;
                    const inset = Theme.frameThickness + Theme.panelGap;
                    check(sidebar.progress > 0 && sidebar.progress < 1, "Vertical sidebar reveal snapped");
                    check(panel.width > 0 && panel.width < sidebar.panelWidth && panel.height > 0 && panel.height < sidebar.panelHeight, "Sidebar did not reveal from its corner");
                    check(sidebar.scrollView.height === sidebar.panelHeight - sidebar.headerHeight - 8 && sidebar.contentBody.width === sidebar.panelWidth - 36, "Vertical sidebar content reflows during reveal");
                    check(Math.abs((side === "left" ? panel.y : frame.height - panel.y - panel.height) - inset) < 0.01, "Vertical sidebar is not aligned to its top or bottom edge");
                    const contentEdge = sidebar.scrollView.mapToItem(frame, 0, side === "left" ? 0 : sidebar.scrollView.height);
                    check(Math.abs((side === "left" ? contentEdge.y : frame.height - contentEdge.y) - inset - 4) < 1, "Vertical sidebar content slides away from its reveal edge: " + contentEdge.y + " inset=" + inset + " side=" + side + " mode=" + mode);
                    SidebarState.close();
                    check(!sidebar.inputRegion.item, "Closing sidebar still accepts input");
                    events.wait(65);
                    check(sidebar.progress > 0 && sidebar.progress < 1 && panel.width < sidebar.panelWidth && panel.height < sidebar.panelHeight,
                        "Sidebar closed as a full-width or full-height strip");
                    events.wait(170);
                    check(!panel.visible, "Sidebar kept a visible surface after closing");
                }
            }
        }
        Config.set("themeAnimations", Enums.AnimationsDisabled);
        Config.set("barSide", Enums.EdgeTop);
    }
    function geometry()
    {
        check(frame.bar && frame.dock, "Frame content missing");
        const shape = frame.surface;
        check(shape.screenSize.x === window.width && shape.screenSize.y === window.height, "Surface does not follow output size");
        check([shape.thickness, shape.startBody.width, shape.endBody.width, shape.dockBody.width].concat(frame.reservations).every(Number.isFinite), "Invalid surface geometry");
        check(frame.reservations.length === 4 && frame.reservations.every(value => value >= frame.thickness), "Frame margins were lost");
        check(frame.reservations[Config.barSide] >= frame.bar.reserve, "Bar reservation lost");
        check(frame.reservations[Config.dockSide] >= frame.dock.thickness + frame.dock.edgeGap, "Dock reservation lost");
        if (Config.barType === Enums.OutFrame) check(shape.startBody.width === 0 && shape.endBody.width === 0, "Out Frame bar kept its fill");
        if (Config.dockType === Enums.OutFrame) check(shape.dockBody.width === 0, "Out Frame dock kept its fill");
        else check(shape.dockBody.width > 0 && shape.dockBody.height > 0, "In Frame dock has no surface");
    }
    function barInteraction()
    {
        const bar = frame.bar;
        const band = bar.sidebarArea;
        check(bar.isHorizontal ? band.width === frame.width : band.height === frame.height, "Sidebar hit area does not span the bar");
        check(frame.leftSidebar.barSide === Config.barSide && frame.rightSidebar.barSide === Config.barSide, "Sidebar clearance uses a different bar edge");
        for (const side of ["left", "right"])
        {
            const along = (bar.isHorizontal ? band.width : band.height) / 2 + (side === "left" ? -6 : 6);
            const x = bar.isHorizontal ? along : band.width / 2;
            const y = bar.isHorizontal ? band.height / 2 : along;
            events.mouseMove(band, x, y, 0);
            check(bar.hoveringBand, "Expanded bar background does not reveal a hover hint");
            events.mouseClick(band, x, y, Qt.LeftButton, Qt.NoModifier, 0);
            check(SidebarState.current === side, "Clicking an empty bar half did not open its sidebar");
            const sidebar = side === "left" ? frame.leftSidebar : frame.rightSidebar;
            const panel = sidebar.panel;
            const gap = Theme.panelGap;
            const vertical = Config.barSide === Enums.EdgeLeft || Config.barSide === Enums.EdgeRight;
            const right = vertical ? Config.barSide === Enums.EdgeRight : side === "right";
            const bottom = Config.barSide === Enums.EdgeBottom || (vertical && side === "right");
            check(Math.abs(panel.x - (right ? frame.width - sidebar.rightInset - panel.width : sidebar.leftInset)) < 0.01, "Sidebar did not follow its bar corner horizontally");
            check(Math.abs(panel.y - (bottom ? frame.height - sidebar.bottomInset - panel.height : sidebar.topInset)) < 0.01, "Sidebar did not follow its bar corner vertically");
            check(panel.width > 0 && panel.height > 0 && sidebar.contentBody.width > 0, "Sidebar content has no visible area");
            if (Config.barSide === Enums.EdgeTop) check(panel.y >= bar.reserve + gap, "Sidebar blends into the top bar");
            if (Config.barSide === Enums.EdgeBottom) check(panel.y + panel.height <= frame.height - bar.reserve - gap, "Sidebar blends into the bottom bar");
            if (Config.barSide === Enums.EdgeLeft) check(panel.x >= bar.reserve + gap, "Sidebar blends into the left bar");
            if (Config.barSide === Enums.EdgeRight) check(panel.x + panel.width <= frame.width - bar.reserve - gap, "Sidebar blends into the right bar");
        }
        SidebarState.close();
    }
    function area(region)
    {
        const item = region.item;
        return (item ? item.width * item.height : region.width * region.height) + region.regions.reduce((sum, child) => sum + area(child), 0);
    }
    LayoutFixture { id: protocolLayout; modelData: Quickshell.screens[0] }
    QtObject
    {
        id: flow
        property bool isCompleted: false
        property bool isResponseRequired: true
        property bool responseVisible: false
        property string message: "Surface regression authentication"
        property string inputPrompt: "Password:"
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
        function submit(text) {}
        function cancelAuthenticationRequest() { tests.cancellations++; overlay.testAgent.isActive = false }
    }
    QtObject
    {
        id: player
        property string dbusName: "test-player"
        property bool isPlaying: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property bool canSeek: true
        property bool canTogglePlaying: true
        property bool canGoNext: true
        property bool canGoPrevious: true
        property bool canRaise: true
        property bool loopSupported: true
        property int loopState: 0
        property bool shuffleSupported: true
        property bool shuffle: false
        property real position: 12
        property real length: 180
        property string identity: "Player"
        property string trackTitle: "A playing track"
        property string trackArtist: "An artist"
        property string trackAlbum: "Album"
        property string trackArtUrl: ""
        function togglePlaying() { isPlaying = !isPlaying }
        function next() {}
        function previous() {}
        function raise() {}
    }
    QtObject
    {
        id: notification
        signal closed()
        property string summary: "Incoming notice"
        property string body: "A longer notification body that wraps across several lines, with enough detail to verify that the Dynamic Island can expand beyond the bar height."
        property string appName: "Test app"
        property string appIcon: ""
        property string image: ""
        property int urgency: 1
        property int expireTimeout: 10
        property bool tracked: true
        function dismiss() { closed() }
    }
    Window
    {
        id: window
        width: 1280; height: 800; visible: true
        Frame { id: frame; anchors.fill: parent; screen: Quickshell.screens[0] }
        OverlayFixture { id: overlay; anchors.fill: parent }
        TestCase { id: events; name: "SurfaceInput"; when: false; optional: true }
        Item
        {
            visible: false
            Repeater
            {
                id: menuProbes
                model: ["Battery", "Bluetooth", "Clock", "Layout", "Media", "Network", "Tray", "Volume"]
                Loader
                {
                    required property string modelData
                    source: Qt.resolvedUrl("modules/ui/bar/menus/Menu" + modelData + ".qml")
                }
            }
        }
        Column
        {
            id: controls
            x: 500; y: 300; width: 220
            visible: false
            Toggle { id: toggleProbe; onToggled: value => checked = value }
            MenuToggle { id: tileProbe; width: parent.width; height: implicitHeight; text: "Wi-Fi"; onToggled: value => checked = value }
            MenuSlider
            {
                id: sliderProbe
                property int muteClicks: 0
                width: parent.width; height: implicitHeight
                text: "Volume"; value: 0.5
                onMoved: value => sliderProbe.value = value
                onIconClicked: muteClicks++
            }
        }
    }
    Timer
    {
        property int step: 0
        property bool checkedMenuEdges: false
        property int previewStep: 0
        property real previewBarHeight: 0
        property int mediaChecks: 0
        property bool mediaRestored: false
        property int sidebarChecks: 0
        property int importChecks: 0
        property int importWait: 0
        interval: 80; repeat: true; running: true
        onTriggered:
        {
            if (!Config.initialized) return;
            try
            {
                if (!checkedMenuEdges)
                {
                    checkedMenuEdges = true;
                    stop();
                    tests.menuEdges();
                    tests.sidebarEdges();
                    start();
                    return;
                }
                if (step < 32)
                {
                    if (step > 0) { tests.geometry(); tests.barInteraction(); }
                    else
                    {
                        ServiceCompositor.backend.windowList = [{id:1,app_id:"test",title:"A window title"}];
                        ServiceCompositor.backend.lastWindowId = 1;
                        ServiceCompositor.backend.focusedWindowId = 1;
                    }
                    Config.set("barType", Math.floor(step / 8) % 2);
                    Config.set("barSide", step % 4);
                    Config.set("dockSide", step < 16 ? (step + 1) % 4 : step % 4);
                    Config.set("dockType", Math.floor(step / 4) % 2);
                }
                else switch (step - 32)
                {
                    case 0:
                        tests.geometry();
                        Config.set("barEnabled", false); Config.set("dockEnabled", false);
                        Config.set("frameThickness", 0);
                        break;
                    case 1:
                        tests.check(!frame.bar && !frame.dock && tests.area(frame.inputRegion) === 0, "Hidden layout still captures input");
                        tests.check(frame.thickness === 0 && frame.surface.thickness === 0 && frame.reservations.every(value => value === 0), "Zero frame thickness keeps application margins");
                        Config.set("frameThickness", 8);
                        Config.set("barEnabled", true); Config.set("dockEnabled", true);
                        Config.set("barScreens", ["disconnected-output"]);
                        break;
                    case 2:
                        tests.geometry();
                        Config.set("barType", Enums.InFrame);
                        Config.set("barScreens", []);
                        MenuState.toggle(Registry.widgets.clock.menu, tests.island(frame.bar));
                        MenuState.menuKeyboard = true;
                        break;
                    case 3:
                        tests.check(frame.keyboardWanted, "Keyboard menu did not request focus");
                        OverlayState.show("settings");
                        break;
                    case 4:
                        tests.ready("settings");
                        tests.check(!MenuState.menuActive, "Overlay did not dismiss layout menu");
                        OverlayState.show("launcher"); OverlayState.hide("launcher");
                        OverlayState.show("power"); OverlayState.show("launcher");
                        break;
                    case 5:
                        tests.ready("launcher");
                        tests.savedPage = overlay.testPage.item;
                        Config.set("themeAnimations", 1);
                        OverlayState.hide("launcher");
                        break;
                    case 6:
                        tests.check(overlay.testPage.item === tests.savedPage && (OverlayState.mounted === "launcher"), "Content unloaded before its exit animation");
                        OverlayState.show("settings");
                        break;
                    case 7:
                        tests.ready("settings"); tests.savedPage = overlay.testPage.item;
                        overlay.testAgent.flow = flow; overlay.testAgent.isActive = true;
                        break;
                    case 8:
                        tests.check(OverlayState.inhibited && overlay.authenticating, "Authentication did not take priority");
                        OverlayState.show("launcher");
                        ServiceCompositor.backend.windowList = [{id:1,app_id:"one",title:"One"},{id:2,app_id:"two",title:"Two"}];
                        ServiceAltTab.cycle(1);
                        tests.check((OverlayState.current === "settings") && !ServiceAltTab.active, "Authentication was interrupted");
                        overlay.dismiss();
                        break;
                    case 9:
                        tests.check(tests.cancellations === 1 && overlay.testPage.item === tests.savedPage, "Authentication discarded the settings session");
                        Config.set("themeAnimations", 0);
                        OverlayState.showDesktopMenu(Quickshell.screens[0].name, 320, 240);
                        break;
                    case 10:
                        tests.ready("desktopMenu");
                        ServiceAltTab.cycle(1);
                        tests.check(!OverlayState.active && ServiceAltTab.active && !ServiceAltTab.presented, "Alt+Tab did not replace desktop menu without flashing");
                        ServiceAltTab.confirm();
                        break;
                    case 11:
                        tests.check(!overlay.modal && !ServiceAltTab.presented, "Quick Alt+Tab kept the overlay active");
                        OverlayState.show("helper");
                        break;
                    case 12: tests.ready("helper"); tests.savedPage = overlay.testPage.item; OverlayState.show("wallpapers"); break;
                    case 13:
                        tests.ready("wallpapers");
                        tests.check(overlay.testPage.item === tests.savedPage, "Wallpaper picker replaced the helper");
                        OverlayState.show("power"); break;
                    case 14:
                        tests.ready("power"); OverlayState.close();
                        ServiceOSD.preview();
                        break;
                    case 15:
                        tests.check(ServiceIsland.view(Quickshell.screens[0].name).kind === "osd" && frame.surface.centerBody.width > 0 && !overlay.visible, "OSD was not presented inside the frame island");
                        Config.set("themeAnimations", 1); ServiceOSD.hide();
                        break;
                    case 16: tests.check(frame.surface.centerBody.width > 0, "Island exit animation disappeared instantly"); break;
                    case 17:
                        if (overlay.visible || frame.surface.centerBody.width > 0.5) { tests.check(++tests.settling < 10, "Overlay never completed its exit"); return; }
                        tests.check(frame.surface.centerBody.width <= 0.5 && !overlay.visible, "Closed overlay kept a surface visible");
                        Config.set("themeAnimations", 2); OverlayState.show("launcher");
                        break;
                    case 18: OverlayState.close(); OverlayState.show("settings"); break;
                    case 19:
                        tests.ready("settings"); OverlayState.close(); Config.set("themeAnimations", 0); break;
                    case 20: SidebarState.toggle("left", Quickshell.screens[0].name); break;
                    case 21:
                        tests.check(frame.leftSidebar.opened && frame.leftSidebar.panel.visible && frame.keyboardWanted, "Left sidebar did not open");
                        frame.leftSidebar.open("settings"); break;
                    case 22:
                        tests.ready("settings"); tests.check(!SidebarState.active, "Sidebar survived opening settings");
                        OverlayState.close(); SidebarState.toggle("right", Quickshell.screens[0].name); break;
                    case 23:
                        tests.check(frame.rightSidebar.opened && frame.rightSidebar.panel.visible, "Right sidebar did not open");
                        SidebarState.toggle("right", "other-output"); break;
                    case 24:
                        tests.check(!frame.sidebarHere && !frame.rightSidebar.panel.visible, "Sidebar appeared on the wrong output");
                        SidebarState.toggle("right", Quickshell.screens[0].name); break;
                    case 25: overlay.testAgent.isActive = true; break;
                    case 26:
                        tests.check(!SidebarState.active, "Authentication did not close the sidebar");
                        overlay.testAgent.isActive = false;
                        tests.check(Registry.widgets.system === undefined && Registry.widgets.user === undefined, "System widget was retained");
                        tests.check(Registry.widgets.notifications === undefined && tests.find(frame.bar, "notificationsWidget") === null,
                            "Removed notification widget remains in the bar");
                        ServiceNotifications.unreadCounter = 3;
                        SidebarState.toggle("right", Quickshell.screens[0].name);
                        ServiceMedia.players = [player]; break;
                    case 27:
                        tests.check(frame.rightSidebar.currentTab === "controls" && ServiceNotifications.unreadCounter === 3,
                            "Opening Control Center marked notification history read");
                        const tabs = tests.find(frame.rightSidebar, "rightSidebarTabs");
                        const notificationsTab = tests.find(tabs, "tab-notifications");
                        events.mouseClick(notificationsTab, notificationsTab.width / 2, notificationsTab.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(frame.rightSidebar.currentTab === "notifications" && tests.find(frame.rightSidebar, "sidebarNotifications") !== null
                            && ServiceNotifications.unreadCounter === 0 && !MenuState.menuActive,
                            "Notifications did not open in the sidebar and mark history read");
                        ServiceNotifications.unreadCounter = 2;
                        tests.check(ServiceNotifications.unreadCounter === 0, "Visible notification history leaves arrivals unread");
                        const duration = tests.find(frame.rightSidebar, "notificationsDndDuration");
                        duration.selected(60);
                        tests.check(ServiceNotifications.dnd && ServiceNotifications.dndMinutes === 60, "Sidebar lost timed DND");
                        ServiceNotifications.setDnd(false);
                        events.keyClick(Qt.Key_Home);
                        tests.check(frame.rightSidebar.currentTab === "controls", "Keyboard cannot select the Control Center tab");
                        SidebarState.close();
                        tests.check(tests.find(frame, "dynamicIsland").shown.kind === "media" && frame.surface.centerBody.width > 0, "Playing media did not populate the island");
                        ServiceNotifications.notificationReceived(notification); break;
                    case 28:
                        tests.check(tests.find(frame, "dynamicIsland").shown.kind === "notification", "Notification did not replace media");
                        tests.check(frame.island.bodyRect.height > Theme.barThickness && tests.find(frame.island, "islandBody").lineCount > 1, "Notification height is still limited by the bar");
                        tests.check(frame.island.bodyRect.height >= tests.find(frame.island, "dynamicIsland").implicitHeight, "Notification content exceeds its frame surface");
                        ServiceOSD.preview(); break;
                    case 29:
                        tests.check(tests.find(frame, "dynamicIsland").shown.kind === "osd", "Value event did not replace notification");
                        tests.check((frame.island.side === Enums.EdgeTop || frame.island.side === Enums.EdgeBottom ? frame.island.bodyRect.height : frame.island.bodyRect.width) === Theme.barThickness, "OSD did not return to compact size");
                        ServiceOSD.hide(); ServiceIsland.dismiss(); break;
                    case 30:
                        tests.check(tests.find(frame, "dynamicIsland").shown.kind === "media", "Media did not return after transients");
                        player.isPlaying = false; break;
                    case 31:
                        tests.check(frame.surface.centerBody.width === 0, "Empty media island kept its background");
                        SidebarState.toggle("right", Quickshell.screens[0].name); break;
                    case 32:
                        tests.check(frame.rightSidebar.opened, "Control center failed to open");
                        const viewport = frame.rightSidebar.scrollView;
                        const body = frame.rightSidebar.contentBody;
                        tests.check(body.x >= body.width * 0.025 / 2 && viewport.width - body.x - body.width >= body.width * 0.025 / 2, "Sidebar viewport clips hover scale");
                        const mediaCard = tests.find(frame.rightSidebar, "controlMedia");
                        const mediaLoader = tests.find(frame.rightSidebar, "controlMediaContent");
                        const volumeControl = tests.find(frame.rightSidebar, "controlVolume"), microphoneControl = tests.find(frame.rightSidebar, "controlMicrophone"), brightnessControl = tests.find(frame.rightSidebar, "controlBrightness");
                        const wifiControl = tests.find(frame.rightSidebar, "controlWifi"), bluetoothControl = tests.find(frame.rightSidebar, "controlBluetooth");
                        tests.check([wifiControl, bluetoothControl].every(control => control.height === 64 && control.subtitle === ""),
                            "Connectivity toggles lost their Material tile layout");
                        tests.check([volumeControl, microphoneControl, brightnessControl].every(control => control.cornerRadius === control.height / 2),
                            "Control center sliders lost their pill shape");
                        tests.check([volumeControl, microphoneControl, brightnessControl].every(control => control.height === 36), "Control center sliders must stay compact");
                        tests.check(volumeControl.width === microphoneControl.width && brightnessControl.width === frame.rightSidebar.contentBody.width, "Audio controls must share a row while brightness stays full-width");
                        tests.check(volumeControl.mapToItem(frame.rightSidebar,0,0).y === microphoneControl.mapToItem(frame.rightSidebar,0,0).y && volumeControl.mapToItem(frame.rightSidebar,0,0).x < microphoneControl.mapToItem(frame.rightSidebar,0,0).x, "Audio controls must be side by side");
                        if (mediaChecks === 0)
                        {
                            tests.check(!player.isPlaying && mediaCard.height > 0 && mediaLoader.item, "Paused media disappeared from the control center");
                            tests.check(!tests.loadedPage(frame.leftSidebar, Qt.resolvedUrl("modules/ui/bar/menus/MenuMedia.qml")), "Media remains in the left sidebar");
                            ServiceMedia.players = []; mediaChecks++; return;
                        }
                        tests.check(mediaCard.height === 0 && !mediaLoader.item.active, "Empty control center retained a media card or playback subscriptions");
                        ServiceMedia.players = [player];
                        SidebarState.close(); player.isPlaying = true;
                        Config.set("barEnabled", false); break;
                    case 33:
                        tests.check(!frame.bar && frame.island && tests.find(frame.island, "dynamicIsland").active, "Island still depends on bar enablement");
                        tests.check(frame.surface.centerBody.width > 0 && frame.island.bodyRect.width > 0, "Island lost its In Frame background with the bar disabled");
                        Config.set("barType", Enums.OutFrame);
                        Config.set("barSide", Enums.EdgeBottom); break;
                    case 34:
                        tests.check(frame.surface.centerBody.y > window.height / 2 && frame.surface.centerBody.width > 0, "Island did not follow the bar to the bottom edge");
                        tests.mediaWidget = tests.find(frame.island, "dynamicIsland");
                        tests.check(tests.mediaWidget.side === Enums.EdgeBottom, "Island orientation was not forwarded to its content");
                        tests.mediaWidget.toggleMenu(); tests.mediaOwner = MenuState.menuOwner; break;
                    case 35:
                        tests.check(MenuState.menuActive && MenuState.menuWidget === tests.mediaWidget, "Media menu failed to open independently");
                        tests.check(!tests.find(tests.mediaWidget, "islandCompactContent").visible, "Media menu duplicated the compact artwork and track details");
                        tests.check(frame.island.bodyRect.height === 0, "Expanded media retained an empty compact island");
                        tests.check(!tests.find(tests.mediaWidget, "islandEqualizer").streaming, "Hidden compact media retained its visualizer subscription");
                        tests.verifyMediaCenter();
                        const expanded = tests.loadedPage(frame.island, Qt.resolvedUrl("modules/ui/bar/menus/MenuMedia.qml"));
                        const expandedEdge = expanded.mapToItem(frame, 0, expanded.height);
                        tests.check(Math.abs(frame.height - expandedEdge.y - Theme.frameThickness) < 1, "Expanded media did not replace the island at its screen edge");
                        const seek = tests.find(frame.island, "mediaSeek");
                        seek.forceActiveFocus();
                        events.keyClick(Qt.Key_End);
                        tests.check(player.position === player.length, "Keyboard seek did not reach the end");
                        events.keyClick(Qt.Key_Home);
                        tests.check(player.position === 0, "Keyboard seek did not reach the start");
                        events.keyClick(Qt.Key_Right);
                        tests.check(Math.abs(player.position - 5) < 0.1, "Keyboard seek did not move forward");
                        const play = tests.find(frame.island, "mediaPlayPause");
                        events.mouseClick(play, play.width / 2, play.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(MenuState.menuKeyboard && play.activeFocus && !player.isPlaying, "Media control did not pause playback and enable keyboard focus");
                        events.keyClick(Qt.Key_Space);
                        tests.check(player.isPlaying, "Keyboard play/pause did not resume playback");
                        player.isPlaying = false;
                        player.trackTitle = ""; ServiceMedia.players = []; break;
                    case 36:
                        tests.check(MenuState.menuActive && MenuState.menuOwner === tests.mediaOwner && tests.find(frame.island, "dynamicIsland") === tests.mediaWidget, "Track loading closed or recreated the menu");
                        tests.verifyMediaCenter();
                        player.trackTitle = "Next track with a much longer title to expand the island"; player.isPlaying = true; ServiceMedia.players = [player]; break;
                    case 37:
                        if (!mediaRestored)
                        {
                            tests.check(MenuState.menuActive && tests.mediaWidget.shown.title === player.trackTitle, "Track update lost the media menu");
                            tests.verifyMediaCenter();
                            MenuState.close(); mediaRestored = true; return;
                        }
                        tests.check(!tests.mediaWidget.menuOpen && tests.find(tests.mediaWidget, "islandCompactContent").visible && frame.island.bodyRect.height > 0, "Closing media did not restore the compact island");
                        player.isPlaying = false;
                        OverlayState.settingsPage = Registry.settings.findIndex(page => page.id === "island");
                        OverlayState.show("settings"); break;
                    case 38:
                        tests.check(tests.find(overlay.testPage.item, "frameStyle-island-0") === null, "Removed island style selector is still present");
                        break;
                    case 39:
                        tests.check(Config.barType === Enums.OutFrame, "Island settings changed the bar style");
                        OverlayState.close(); Config.set("themeAnimations", 2);
                        SidebarState.toggle("left", Quickshell.screens[0].name); break;
                    case 40:
                        tests.check(frame.leftSidebar.progress > 0 && frame.leftSidebar.progress < 1, "Sidebar reveal snapped");
                        tests.check(frame.leftSidebar.panel.width > 0 && frame.leftSidebar.panel.width < frame.leftSidebar.panelWidth, "Sidebar background does not expand from its edge");
                        tests.check(frame.leftSidebar.panel.x === frame.leftSidebar.leftInset, "Sidebar slides instead of revealing from its edge");
                        tests.check(frame.leftSidebar.contentBody.width === frame.leftSidebar.panelWidth - 36, "Sidebar content reflows during its reveal");
                        tests.slideBefore = frame.leftSidebar.progress; SidebarState.close();
                        tests.check(Math.abs(frame.leftSidebar.progress - tests.slideBefore) < 0.001, "Reversing a reveal jumped");
                        SidebarState.toggle("left", Quickshell.screens[0].name); break;
                    case 41:
                        tests.check(frame.leftSidebar.progress > tests.slideBefore, "Reopened sidebar lost its smooth motion");
                        const canvas = protocolLayout.canvasSurface;
                        tests.check(canvas.exclusionMode === ExclusionMode.Ignore && canvas.exclusiveZone === -999, "Canvas exclusiveZone assignment overrides Ignore mode");
                        tests.check(canvas.reserveAnchors.top && canvas.reserveAnchors.bottom && canvas.reserveAnchors.left && canvas.reserveAnchors.right, "Canvas no longer covers all output edges");
                        tests.check(canvas.width === Quickshell.screens[0].width && canvas.height === Quickshell.screens[0].height, "Canvas was inset into the work area");
                        Config.set("themeAnimations", 0); SidebarState.close(); ServiceMedia.players = [];
                        Config.set("barEnabled", true); Config.set("barSide", Enums.EdgeTop);
                        Config.set("barHideAuto", true); Config.set("barHideSmart", false);
                        break;
                    case 42:
                        frame.bar.revealed = false;
                        events.mouseMove(frame, frame.width / 2 - 6, 1, 0);
                        tests.check(frame.bar.revealed, "Auto-hide edge no longer reveals the bar");
                        events.mouseMove(frame.bar.sidebarArea, frame.width / 2 - 6, frame.bar.reserve / 2, 0);
                        tests.check(frame.bar.revealWanted, "Auto-hide does not stay revealed on empty bar space");
                        events.mouseClick(frame.bar.sidebarArea, frame.width / 4, frame.bar.reserve / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(SidebarState.current === "left", "Expanded auto-hide bar no longer opens a sidebar");
                        const clock = tests.slot(frame.bar, "clock");
                        tests.check(clock !== null, "Clock widget did not load");
                        events.mouseClick(clock, clock.width / 2, clock.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(!SidebarState.active && MenuState.menuActive && MenuState.menuCurrent === String(Registry.widgets.clock.menu), "Bar background or sidebar swallowed a widget click");
                        MenuState.close(); Config.set("barHideAuto", false);
                        OverlayState.settingsPage = Registry.settings.findIndex(page => page.id === "bar");
                        OverlayState.show("settings"); break;
                    case 43:
                        tests.check(!tests.find(overlay.testPage.item, "menuStyle-0") && !tests.find(overlay.testPage.item, "menuStyle-1"),
                            "Settings still offers an attached sidebar");
                        OverlayState.close();
                        tests.frameBeforeSidebar = tests.barShape();
                        SidebarState.toggle("left", Quickshell.screens[0].name); break;
                    case 44:
                        tests.check(frame.leftSidebar.panel.x === Theme.frameThickness + Theme.panelGap, "Left sidebar has the wrong frame gap");
                        tests.check(tests.barShape() === tests.frameBeforeSidebar, "Opening the sidebar changed the frame contour");
                        const floatingSurface = tests.find(frame.leftSidebar, "floatingPanelFill");
                        tests.check(floatingSurface && floatingSurface.visible && floatingSurface.color === frame.surface.fillColor
                            && floatingSurface.border.width === frame.surface.borderWidth && floatingSurface.border.color === frame.surface.borderColor,
                            "Sidebar does not share the frame material and outline");
                        SidebarState.toggle("right", Quickshell.screens[0].name); break;
                    case 45:
                        tests.check(frame.rightSidebar.panel.x + frame.rightSidebar.panel.width === frame.width - Theme.frameThickness - Theme.panelGap,
                            "Right sidebar has the wrong frame gap");
                        tests.check(tests.barShape() === tests.frameBeforeSidebar, "Switching sidebars changed the frame contour");
                        break;
                    case 46:
                        tests.check(frame.rightSidebar.opened, "Switching sidebars did not open the right sidebar");
                        ServiceCompositor.backend.lastWindowId = 1; ServiceCompositor.backend.focusedWindowId = null;
                        const clockAfterSidebar = tests.slot(frame.bar, "clock");
                        events.mouseClick(clockAfterSidebar, clockAfterSidebar.width / 2, clockAfterSidebar.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(!SidebarState.active && MenuState.menuActive, "Opening a menu did not replace the sidebar");
                        ServiceCompositor.backend.focusedWindowId = 1;
                        tests.check(MenuState.menuActive, "Restoring focus after a sidebar dismissed the new menu");
                        ServiceCompositor.backend.focusedWindowId = 2;
                        tests.check(!MenuState.menuActive, "An actual window switch no longer dismisses menus");
                        player.isPlaying = true; ServiceMedia.players = [player];
                        Config.set("barSide", Enums.EdgeBottom); Config.set("dockSide", Enums.EdgeTop);
                        SidebarState.toggle("left", Quickshell.screens[0].name); break;
                    case 47:
                        const media = tests.find(frame.island, "dynamicIsland");
                        tests.check(media && media.active, "Independent media island is unavailable");
                        events.mouseClick(media, media.width / 2, media.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(!SidebarState.active && MenuState.menuWidget === media, "Island menu requires a second click after a sidebar");
                        events.mouseClick(frame.bar.sidebarArea, frame.width / 4, frame.bar.reserve / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(SidebarState.current === "left" && !MenuState.menuActive, "Sidebar no longer replaces a menu on the first click");
                        events.mouseClick(frame, frame.width / 2, frame.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(!SidebarState.active, "Moving the dismiss area broke outside clicks");
                        SidebarState.toggle("right", Quickshell.screens[0].name); break;
                    case 48:
                        const mediaFloating = tests.find(frame.island, "dynamicIsland");
                        events.mouseClick(mediaFloating, mediaFloating.width / 2, mediaFloating.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(!SidebarState.active && MenuState.menuWidget === mediaFloating, "Floating sidebar blocks the island menu");
                        MenuState.close(); SidebarState.toggle("left", Quickshell.screens[0].name);
                        const app = tests.dockItem(frame.dock);
                        tests.check(app !== null, "Dock fixture has no application");
                        events.mouseClick(app, app.width / 2, app.height / 2, Qt.RightButton, Qt.NoModifier, 0);
                        tests.check(!SidebarState.active && frame.dock.keyboardWanted, "Dock menu requires a second click after a sidebar");
                        SidebarState.toggle("right", Quickshell.screens[0].name);
                        tests.check(!frame.dock.keyboardWanted, "Sidebar did not replace the dock menu");
                        SidebarState.close();
                        ServiceMedia.players = [];
                        controls.visible = true; break;
                    case 49:
                        events.mouseClick(toggleProbe, toggleProbe.width / 2, toggleProbe.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(toggleProbe.checked, "Shared settings toggle does not emit changes");
                        events.mouseClick(tileProbe, tileProbe.width / 2, tileProbe.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(tileProbe.checked && String(tileProbe.children[0].color) === String(Theme.colorAccent), "Enabled control tile does not use the shared active surface");
                        const sliderPointer = tests.find(sliderProbe, "controlSliderPointer");
                        events.mousePress(sliderPointer, 80, 18, Qt.LeftButton, Qt.NoModifier, 0);
                        events.mouseMove(sliderPointer, sliderPointer.width, 18, 0);
                        events.mouseRelease(sliderPointer, sliderPointer.width, 18, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(sliderProbe.value === 1 && tests.find(sliderProbe, "controlSliderFill").height === sliderProbe.height, "Slider drag or full-height fill failed");
                        events.mouseWheel(sliderPointer, 100, 18, 0, -120, Qt.NoButton, Qt.NoModifier, 0);
                        tests.check(sliderProbe.value === 0.95, "Control slider scrolling failed");
                        events.mouseClick(tests.find(sliderProbe, "controlSliderIcon"), 18, 18, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(sliderProbe.muteClicks === 1 && sliderProbe.value === 0.95, "Mute click changed the slider level");
                        events.keyClick(Qt.Key_Home);
                        tests.check(sliderProbe.value === 0, "Slider Home key failed");
                        events.keyClick(Qt.Key_End);
                        tests.check(sliderProbe.value === 1, "Slider End key failed");
                        sliderProbe.available = false;
                        events.mouseClick(sliderPointer, 80, 18, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(sliderProbe.value === 1, "Unavailable slider accepted input");
                        controls.visible = false;
                        OverlayState.settingsPage = 0; OverlayState.show("settings"); break;
                    case 50:
                        OverlayState.settingsPage = Registry.settings.findIndex(page => page.id === "bar"); break;
                    case 51:
                        const filledBar = tests.find(overlay.testPage.item, "frameStyle-bar-" + Enums.Filled);
                        tests.check(filledBar && filledBar.filled && filledBar.width <= 150, "Filled bar preview is missing");
                        filledBar.clicked(); OverlayState.close();
                        Config.set("dockType", Enums.Filled);
                        Config.set("barSide", Enums.EdgeTop); Config.set("dockSide", Enums.EdgeTop);
                        player.isPlaying = true; ServiceMedia.players = [player]; break;
                    case 52:
                    case 53:
                    case 54:
                    case 55:
                        tests.check(Config.barType === Enums.Filled && frame.bar.filled && frame.dock.filled, "Filled styles are not independent");
                        tests.check(frame.island.side === Config.barSide && tests.find(frame.island, "dynamicIsland").side === Config.barSide, "Island position or content orientation does not follow the bar");
                        tests.check(frame.bar.inFrame && frame.dock.inFrame, "Filled is detached from the frame");
                        const horizontal = Config.barSide === Enums.EdgeTop || Config.barSide === Enums.EdgeBottom;
                        const span = horizontal ? frame.width : frame.height;
                        const strips = [frame.surface.startBody, frame.surface.centerBody, frame.surface.endBody, frame.surface.dockBody].filter(rect => rect.width > 0 && rect.height > 0);
                        tests.check(strips.length === 1, "Same-edge Filled backgrounds are drawn more than once");
                        tests.check(strips.every(rect => (horizontal ? rect.width : rect.height) >= span), "Filled does not cover the entire edge");
                        tests.check(strips.every(rect => (horizontal ? rect.x : rect.y) < 0), "Filled ends are not attached to screen corners");
                        tests.check(frame.dock.edgeGap === Math.max(Theme.frameThickness, frame.dock.barDepth), "Filled dock retains the floating gap");
                        tests.check(frame.reservations[Config.barSide] >= frame.bar.reserve, "Filled bar has no reservation");
                        if (step - 32 < 55)
                        {
                            const side = [Enums.EdgeLeft, Enums.EdgeBottom, Enums.EdgeRight][step - 84];
                            Config.set("barSide", side); Config.set("dockSide", side);
                        }
                        else Config.set("themeStyle", Enums.ThemeLight);
                        break;
                    case 56:
                        tests.check(frame.surface.fillColor === Theme.frameColor && Theme.light, "Filled ignores the light frame theme");
                        ServiceMedia.players = []; break;
                    case 57:
                        tests.check(frame.island.bodyRect.width === 0, "Empty island kept its Filled background");
                        Config.set("barType", Enums.InFrame); Config.set("dockType", Enums.OutFrame);
                        OverlayState.settingsPage = Registry.settings.findIndex(page => page.id === "dock");
                        OverlayState.show("settings"); break;
                    case 58:
                        tests.check(!frame.bar.filled && frame.surface.startBody.width > 0 && frame.surface.startBody.width < frame.width, "Returning to In Frame retained full-side fill");
                        tests.check(frame.dock.container.color.a === 0, "Out Frame retained the dock fill");
                        const filledDock = tests.find(overlay.testPage.item, "frameStyle-dock-" + Enums.Filled);
                        tests.check(filledDock && filledDock.filled, "Filled dock preview is missing");
                        const badges=tests.find(overlay.testPage.item,"dockNotificationBadges");
                        tests.check(badges && tests.find(tests.find(overlay.testPage.item,"dockStyleOptions"),"dockNotificationBadges")===badges,"Notification badges are outside Dock style");
                        badges.toggled(false);tests.check(!Config.dockBadges,"Dock notification badges did not disable");
                        badges.toggled(true);tests.check(Config.dockBadges,"Dock notification badges did not enable");
                        filledDock.clicked();
                        OverlayState.settingsPage = Registry.settings.findIndex(page => page.id === "island"); break;
                    case 59:
                        tests.check(Config.dockType === Enums.Filled && Config.barType === Enums.InFrame, "Dock card changed another style");
                        tests.check(tests.find(overlay.testPage.item, "frameStyle-island-2") === null, "Removed Filled island selector is still present");
                        break;
                    case 60:
                        tests.check(Config.barType === Enums.InFrame, "Island settings changed another style");
                        OverlayState.close(); Config.set("dockType", Enums.OutFrame);
                        player.isPlaying = true; ServiceMedia.players = [player];
                        break;
                    case 61:
                        tests.check(frame.surface.startBody.width > 0 && frame.surface.endBody.width > 0 && frame.surface.centerBody.height > 0 && frame.surface.centerBody.height < frame.height, "Island must wrap its content in frame");
                        Config.set("barType", Enums.Filled); break;
                    case 62:
                        tests.check(frame.surface.startBody.height >= frame.height && frame.surface.centerBody.width === 0, "Filled bar duplicates the island body on the same edge");
                        tests.check(tests.find(frame.island, "dynamicIsland").active && frame.island.bodyRect.width > 0, "Merging backgrounds hid island content or input geometry");
                        Config.set("barType", Enums.OutFrame); break;
                    case 63:
                        tests.check(frame.surface.centerBody.width > 0, "Out Frame bar changed the island background");
                        Config.set("barType", Enums.Filled); break;
                    case 64:
                        tests.check(frame.surface.startBody.height >= frame.height && frame.surface.centerBody.width === 0, "Covered In Frame island background was not merged");
                        Config.set("barType", Enums.OutFrame); Config.set("themeAnimations", 0); Config.set("dockEnabled", false);
                        ServiceNotifications.notificationReceived(notification); break;
                    case 65:
                    case 66:
                    case 67:
                    case 68:
                        const notice = tests.find(frame.island, "dynamicIsland");
                        const bodyText = tests.find(notice, "islandBody");
                        tests.check(notice.shown.kind === "notification" && !notice.compact && bodyText.lineCount > 1, "Notification is collapsed to an icon on a bar edge");
                        tests.check(frame.island.bodyRect.width >= notice.implicitWidth && frame.island.bodyRect.height >= notice.implicitHeight, "Expanded notification does not fit its surface");
                        const surface = tests.find(frame.island, "islandNotificationSurface");
                        tests.check(surface.visible && surface.color === Theme.frameColor && surface.width === frame.island.bodyRect.width && surface.height === frame.island.bodyRect.height, "Expanded notification lets underlying shell content show through");
                        tests.check(frame.reservations[Config.barSide] === frame.bar.reserve, "Transient notifications resized application reservations");
                        if (step - 32 < 68) Config.set("barSide", [Enums.EdgeTop, Enums.EdgeLeft, Enums.EdgeBottom][step - 97]);
                        else { Config.set("themeAnimations", 2); ServiceIsland.dismiss(); }
                        break;
                    case 69:
                        if (tests.find(frame.island, "dynamicIsland").shown.kind !== "media") return;
                        ServiceNotifications.notificationReceived(notification); break;
                    case 70:
                        tests.check(tests.find(frame.island, "dynamicIsland").contentOpacity < 1, "Island content transition snapped");
                        break;
                    case 71:
                        tests.check(frame.island.bodyRect.height > Theme.barThickness, "Fluid notification did not start expanding");
                        ServiceOSD.preview(); break;
                    case 72:
                        ServiceOSD.hide(); ServiceIsland.dismiss(); break;
                    case 73:
                        if (tests.find(frame.island, "dynamicIsland").shown.kind !== "media" || tests.find(frame.island, "dynamicIsland").contentOpacity < 0.99) return;
                        Config.set("themeAnimations", 0); Config.set("dockEnabled", true);
                        OverlayState.settingsPage = 0; OverlayState.show("settings"); break;
                    case 74:
                        OverlayState.settingsPage = Registry.settings.findIndex(page => page.id === "bar"); break;
                    case 75:
                        const islandsBar = tests.find(overlay.testPage.item, "frameStyle-bar-" + Enums.Islands);
                        tests.check(islandsBar && islandsBar.islands && islandsBar.width <= 150, "Islands bar preview is missing");
                        islandsBar.clicked(); OverlayState.close();
                        Config.set("dockType", Enums.Islands); Config.set("themeStyle", Enums.ThemeDark);
                        Config.set("barSide", Enums.EdgeTop); Config.set("dockSide", Enums.EdgeTop); break;
                    case 76:
                    case 77:
                    case 78:
                    case 79:
                        tests.check(frame.bar.islands && frame.dock.islands && !frame.bar.inFrame && !frame.dock.inFrame, "Islands style still joins the frame");
                        const capsules = [frame.surface.startBody, frame.surface.endBody];
                        tests.check(frame.surface.detachedBar && frame.surface.barSmoothing === 0 && frame.surface.dockBody.width === 0,
                            "Islands bar joined the screen frame");
                        tests.check(capsules.every(rect => rect.width > 0 && rect.height > 0), "Bar groups have no independent capsule backgrounds");
                        for (const capsule of capsules)
                        {
                            const gap = Config.barSide === Enums.EdgeTop ? capsule.y : Config.barSide === Enums.EdgeBottom ? frame.height - capsule.y - capsule.height
                                : Config.barSide === Enums.EdgeLeft ? capsule.x : frame.width - capsule.x - capsule.width;
                            tests.check(Math.abs(gap - Theme.frameThickness - frame.bar.surfaceGap) < 0.01, "Islands bar has no clear frame gap");
                        }
                        tests.check(frame.dock.container.color === Theme.frameColor && frame.dock.edgeGap > frame.dock.barDepth, "Islands dock has no separate fill or gap");
                        tests.check(frame.reservations[Config.barSide] >= frame.bar.reserve, "Islands bar lost its reserved margin");
                        tests.check(frame.island.side === Config.barSide && frame.surface.centerBody.width > 0, "Islands bar altered the Dynamic Island style");
                        if (step - 32 < 79)
                        {
                            const side = [Enums.EdgeLeft, Enums.EdgeBottom, Enums.EdgeRight][step - 108];
                            Config.set("barSide", side); Config.set("dockSide", side);
                        }
                        else Config.set("themeStyle", Enums.ThemeLight);
                        break;
                    case 80:
                        tests.check(frame.dock.container.color === Theme.frameColor && frame.surface.paintColor === Theme.frameColor, "Islands colors ignore the light theme");
                        Config.set("dockType", Enums.OutFrame);
                        OverlayState.settingsPage = Registry.settings.findIndex(page => page.id === "dock"); OverlayState.show("settings"); break;
                    case 81:
                        const islandsDock = tests.find(overlay.testPage.item, "frameStyle-dock-" + Enums.Islands);
                        tests.check(islandsDock && islandsDock.islands && frame.dock.container.color.a === 0, "Islands dock preview or style reset failed");
                        islandsDock.clicked(); OverlayState.close(); break;
                    case 82:
                        tests.check(Config.dockType === Enums.Islands && Config.barType === Enums.Islands, "Islands dock card changed the wrong setting");
                        frame.bar.revealed = false; frame.dock.revealed = false; break;
                    case 83:
                        tests.check([frame.surface.startBody, frame.surface.endBody].every(rect => rect.x >= frame.width), "Hidden bar left capsule backgrounds visible");
                        tests.check(frame.dock.container.x >= frame.width, "Hidden Islands dock left its background onscreen");
                        frame.bar.revealed = true; frame.dock.revealed = true;
                        OverlayState.settingsPage = 0; OverlayState.show("settings"); break;
                    default:
                        if (sidebarChecks === 0 && step - 32 >= 50 && step - 116 < Registry.settings.length)
                        {
                            tests.ready("settings");
                            tests.check(tests.loadedPage(overlay.testPage.item, Registry.settings[step - 116].page) !== null, "Settings page failed to load after relocation: " + Registry.settings[step - 116].id);
                            if (Registry.settings[step - 116].id === "updates")
                            {
                                const imports = tests.find(overlay.testPage.item, "resourceImports");
                                tests.check(imports !== null, "Updates import section is missing");
                                if (importChecks === 0)
                                {
                                    tests.check(!imports.expanded, "Import section is not collapsed by default");
                                    imports.expanded = true; importChecks++; return;
                                }
                                if (importChecks === 1)
                                {
                                    if ((ServiceResources.busy || ServiceResources.entries.length === 0) && importWait++ < 20) return;
                                    tests.check(ServiceResources.entries.map(entry => entry.id).join(",") === "compositor,dots,greeter,wallpapers", "Import catalog did not load");
                                    tests.find(imports, "importResource-dots").clicked();
                                    tests.check(ServiceResources.pending && ServiceResources.pending.id === "dots", "Dots import did not request confirmation");
                                    const confirmation = tests.find(overlay.testPage.item, "resourceConfirmation");
                                    tests.check(confirmation && confirmation.visible && confirmation.modal, "Import confirmation is not a modal popup");
                                    tests.find(confirmation.contentItem, "acceptConfirmation").clicked();
                                    tests.check(ServiceResources.pending && ServiceResources.error !== "" && !ServiceResources.busy, "Missing terminal did not preserve the confirmation");
                                    ServiceResources.pending = null;
                                    tests.find(imports, "importResource-greeter").clicked();
                                    tests.check(ServiceResources.pending.kind === "greeter", "Greeter import is unavailable");
                                    imports.expanded = false;
                                    tests.check(ServiceResources.pending === null, "Closing imports left a pending replacement");
                                    imports.expanded = true; importChecks++; return;
                                }
                                if (importChecks === 2)
                                {
                                    if (ServiceResources.busy) return;
                                    tests.find(imports, "importResource-wallpapers").clicked();
                                    const confirmation = tests.find(overlay.testPage.item, "resourceConfirmation");
                                    tests.find(confirmation.contentItem, "acceptConfirmation").clicked();
                                    tests.check(ServiceResources.busy && ServiceUpdate.resourcesBusy, "Import and updater can run concurrently");
                                    importChecks++; return;
                                }
                                if (importChecks === 3)
                                {
                                    if (ServiceResources.busy) return;
                                    tests.check(ServiceResources.error === "" && ServiceResources.message !== "" && !ServiceUpdate.resourcesBusy, "Wallpaper import did not finish cleanly");
                                    imports.expanded = false; importChecks++;
                                }
                            }
                            if (Registry.settings[step - 116].id === "appearance")
                            {
                                const wallpaperPreview = tests.find(overlay.testPage.item, "currentWallpaperPreview");
                                tests.check(wallpaperPreview && wallpaperPreview.wallpaper === Config.wallpaperCurrent && wallpaperPreview.height === 172, "Appearance lost its shared wallpaper preview");
                                let row = wallpaperPreview.parent;
                                while (row && row.controlAvailableWidth === undefined) row = row.parent;
                                tests.check(row && row.stacked, "Wallpaper preview is outside a settings row");
                            }
                            if (Registry.settings[step - 116].id === "components")
                            {
                                const visualizer = tests.find(overlay.testPage.item, "visualizerOptions");
                                tests.check(visualizer, "Visualizer foldout is missing");
                                if (!visualizer.expanded) { visualizer.expanded = true; return; }
                                const bars = tests.find(overlay.testPage.item, "equalizerStyle-" + Enums.EqualizerBars);
                                const waves = tests.find(overlay.testPage.item, "equalizerStyle-" + Enums.EqualizerWaves);
                                tests.check(bars && waves && waves.kind === "equalizer" && waves.width <= 150, "Equalizer style previews are missing");
                                if (previewStep === 0)
                                {
                                    const page = tests.loadedPage(overlay.testPage.item, Registry.settings[step - 116].page);
                                    page.contentY = Math.max(0, Math.min(page.contentHeight - page.height, waves.mapToItem(page.contentItem, 0, 0).y - 120));
                                    previewBarHeight = tests.find(bars, "equalizerBar").height;
                                    events.mouseMove(waves, waves.width / 2, waves.height / 2, 0);
                                    waves.forceActiveFocus(Qt.TabFocusReason);
                                    previewStep++; return;
                                }
                                tests.check(!waves.previewing && !bars.previewing, "Visualizer hover or focus starts a preview animation");
                                tests.check(tests.find(bars, "equalizerBar").height === previewBarHeight, "Static visualizer preview changed height");
                                waves.focus = false;
                                events.mouseMove(window.contentItem, 2, 2, 0);
                                waves.clicked();
                                tests.check(Config.equalizerStyle === Enums.EqualizerWaves && waves.current, "Wave preview did not select the global style");
                                tests.check(tests.find(frame, "islandEqualizer").style === Enums.EqualizerBars, "Global Waves selection overrode the island Bars style");
                                bars.clicked();
                                tests.check(Config.equalizerStyle === Enums.EqualizerBars && bars.current, "Bars preview did not restore the global style");
                            }
                            if (step - 116 + 1 < Registry.settings.length)
                            {
                                OverlayState.settingsPage = step - 116 + 1;
                                break;
                            }
                        }
                        if (sidebarChecks === 0)
                        {
                            Config.set("themeAnimations", 0); Config.set("barSide", Enums.EdgeTop);
                            OverlayState.close(); SidebarState.toggle("left", Quickshell.screens[0].name);
                            sidebarChecks++; return;
                        }
                        if (sidebarChecks === 1)
                        {
                            const user = tests.find(frame.leftSidebar, "sidebarUser");
                            const wallpaper = tests.find(frame.leftSidebar, "sidebarWallpaper");
                            tests.check(frame.leftSidebar.opened && user && wallpaper && tests.find(frame.leftSidebar, "sidebarReload"), "Left sidebar cards or session buttons are missing");
                            tests.check(wallpaper.wallpaper === Config.wallpaperCurrent && user.mapToItem(frame.leftSidebar.contentBody, 0, 0).y < wallpaper.mapToItem(frame.leftSidebar.contentBody, 0, 0).y, "Left sidebar wallpaper does not follow the user card");
                            frame.leftSidebar.scrollView.contentY = 0;
                            events.mouseClick(user, user.width / 2, user.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                            tests.check(OverlayState.current === "settings" && Registry.settings[OverlayState.settingsPage].id === "user" && !SidebarState.active, "User card does not open user settings");
                            OverlayState.close(); SidebarState.toggle("left", Quickshell.screens[0].name);
                            sidebarChecks++; return;
                        }
                        if (sidebarChecks === 2)
                        {
                            const wallpaper = tests.find(frame.leftSidebar, "sidebarWallpaper");
                            events.mouseClick(wallpaper, wallpaper.width / 2, wallpaper.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                            tests.check(OverlayState.current === "wallpapers" && !SidebarState.active, "Wallpaper card does not replace the sidebar with the picker");
                            OverlayState.close(); SidebarState.toggle("left", Quickshell.screens[0].name);
                            sidebarChecks++; return;
                        }
                        if (sidebarChecks < 6)
                        {
                            const names = ["sidebarLauncher", "sidebarSettings", "sidebarPower"];
                            const destinations = ["launcher", "settings", "power"];
                            const index = sidebarChecks - 3;
                            const button = tests.find(frame.leftSidebar, names[index]);
                            events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                            tests.check(OverlayState.current === destinations[index] && !SidebarState.active, "Sidebar action did not open " + destinations[index]);
                            OverlayState.close(); SidebarState.toggle("left", Quickshell.screens[0].name);
                            sidebarChecks++; return;
                        }
                        SidebarState.close(); OverlayState.close();
                        ServiceMedia.players = [];
                        for (let i = 0; i < menuProbes.count; i++)
                        {
                            const probe = menuProbes.itemAt(i);
                            tests.check(probe.status === Loader.Ready && probe.item.implicitHeight > 0, "Bar menu did not load: " + probe.modelData);
                        }
                        console.log("SURFACES_PASSED"); Qt.quit(); break;
                }
                step++;
            }
            catch (error) { console.error("SURFACES_FAILED", step, error); Qt.quit() }
        }
    }
}
''')
    if scenario is not None:
        scenario(base)
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
               XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
               PATH=str(base / "bin") + os.pathsep + os.environ["PATH"],
               DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-session-bus",
               DBUS_SYSTEM_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-system-bus", NIRI_SOCKET="/tmp/bloodyshell-test-no-niri")
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=40)
    print(result.stdout)
    assert result.returncode == 0 and "SURFACES_PASSED" in result.stdout, "Surface integration checks failed"
    assert not re.search(r"SURFACES_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", result.stdout), "Surface QML error"


def audio_dropdown_fixture(base):
    audio = base / "modules/services/ServiceAudio.qml"
    source = audio.read_text()
    for name in ("sinks", "sources"):
        source = re.sub(r"readonly property var " + name + r":[^\n]+", "property var " + name + ": []", source)
    source = source.replace("readonly property var sink: Pipewire.defaultAudioSink", "property var sink: null")
    source = source.replace("readonly property var source: Pipewire.defaultAudioSource", "property var source: null")
    source = source.replace("if (node) Pipewire.preferredDefaultAudioSink = node", "if (node) sink = node")
    source = source.replace("if (node) Pipewire.preferredDefaultAudioSource = node", "if (node) source = node")
    audio.write_text(source)
    (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/frame"
import "modules/ui/bar/menus"
ShellRoot {
    id: tests
    function check(ok,message) {if(!ok)throw new Error(message);}
    function find(item,name) {if(item.objectName===name)return item;for(const child of item.children||[]){const found=find(child,name);if(found)return found;}return null;}
    Window {
        id:window;visible:true;width:640;height:720;color:Theme.colorSolid
        Frame {
            id:frame;anchors.fill:parent;screen:Quickshell.screens[0]
            MenuVolume {id:menu;x:24;y:30;width:implicitWidth;height:implicitHeight}
        }
        TestCase {id:events;name:"AudioDropdowns";when:false;optional:true}
    }
    Timer {interval:250;running:Config.initialized;onTriggered:{try{
        Config.set("barEnabled",false);Config.set("dockEnabled",false);Config.set("islandEnabled",false);
        const outputA={id:1,description:"Speakers",audio:{volume:.45,muted:false}};
        const outputB={id:2,description:"Headphones",audio:{volume:.55,muted:false}};
        const outputC={id:3,description:"Headphones",audio:{volume:.65,muted:false}};
        const inputA={id:10,description:"Microphone",audio:{volume:.5,muted:false}};
        const inputB={id:11,description:"USB Microphone",audio:{volume:.75,muted:false}};
        ServiceAudio.sinks=[outputA,outputA,outputB,outputC];ServiceAudio.sources=[inputA,inputA,inputB];
        ServiceAudio.sink=outputA;ServiceAudio.source=inputA;events.wait(50);
        const output=find(menu,"audioDevice-0"),input=find(menu,"audioDevice-2");
        check(output&&input&&output.entries.length===3&&input.entries.length===2,"Device dropdowns contain duplicate IDs or merge distinct devices with the same name");
        check(output.x===0&&output.width===menu.width-Theme.menuPadding*2,"Device selector must use the full menu content width");
        ServiceAudio.sink=null;
        check(output.enabled,"Device selection is disabled when the default device disappears");
        output.toggle();events.wait(30);output.choose(2);events.wait(300);
        check(ServiceAudio.sink.id===3,"Selecting a device did not recover a missing default output");
        for(const mode of [0,1,2]) {
            Config.set("themeAnimations",mode);menu.visible=true;ServiceAudio.sink=outputA;ServiceAudio.source=inputA;
            const collapsed=menu.implicitHeight;
            events.mouseClick(output,output.width/2,output.height/2,Qt.LeftButton);events.wait(80);
            check(output.open&&!frame.popupHere&&!OverlayState.settingsPopup,"Device list opened outside the sound menu");
            const panel=find(output,"inlineMenuDropdownPanel");
            const background=find(output,"inlineMenuDropdownBackground"),trigger=find(output,"menuDropdownTrigger");
            check(panel&&panel.height>0&&menu.implicitHeight>collapsed&&background.height===output.height
                && panel.mapToItem(output,0,0).y===trigger.height&&trigger.text==="Speakers",
                "Device choices did not unfold from the selected button on one surface");
            const options=find(output,"inlineMenuDropdownOptions");
            check(options&&options.count===2&&options.activeFocus&&options.currentIndex===0,"Expansion repeated the selected device or lost keyboard focus");
            events.keyClick(Qt.Key_Down);
            events.keyClick(Qt.Key_Up);
            events.keyClick(Qt.Key_Return);
            for(let attempt=0;menu.implicitHeight!==collapsed&&attempt<25;attempt++)events.wait(20);
            check(ServiceAudio.sink.id===2&&!output.open&&menu.implicitHeight===collapsed,"Device selection picked a duplicate or kept the list expanded");
            check(trigger.activeFocus&&trigger.text==="Headphones","Device selection did not return focus to the new value");
            output.toggle();
            input.toggle();events.wait(60);
            check(input.open&&!output.open,"Output and input selectors expanded simultaneously");
            input.choose(0);events.wait(300);
            check(ServiceAudio.source.id===11,"Input selection changed the wrong device");
            output.toggle();events.wait(60);menu.visible=false;events.wait(300);
            check(!output.open&&!frame.popupHere&&!OverlayState.settingsPopup,"Hiding the sound menu retained a dropdown or input grab");
        }
        console.log("AUDIO_DROPDOWNS_PASSED unique IDs, full-width inline lists, keyboard focus, exclusive expansion, selection and cleanup");
        console.log("SURFACES_PASSED");Qt.quit();
    }catch(error){console.error("SURFACES_FAILED audio dropdown",error);Qt.quit();}}}
}
''')


def fullscreen_fixture(base):
    island = base / "modules/services/ServiceIsland.qml"
    island.write_text(island.read_text().replace("primaryOutputFor(Quickshell.screens, Config.barScreens)", 'primaryOutputFor([{name:"A"},{name:"B"}], Config.barScreens)'))
    compositor = base / "modules/compositors/Niri.qml"
    source = compositor.read_text().replace("id: niri", "id: niri\n    property var testOutputs: []\n    property var testActions: []", 1)
    source = source.replace("fullscreenScreens(Quickshell.screens)", "fullscreenScreens(testOutputs)")
    source = re.sub(r"function action\(name, args = \{\}\) \{[^\n]+\}",
                    "function action(name, args = {}) { testActions = testActions.concat([{name:name, id:args.id}]) }", source, count=1)
    compositor.write_text(source)
    (base / "shell.qml").write_text(r'''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Wayland
import "modules/core"
import "modules/services"
import "modules/ui/layout"
import "modules/ui/frame"

ShellRoot {
    Window {
        id: window; visible: true; width: 1280; height: 800
        QtObject { id: outputA; property string name:"A"; property int width:1280; property int height:800 }
        QtObject { id: outputB; property string name:"B"; property int width:1920; property int height:1080 }
        LayoutFixture { id: layout; modelData: outputA; Component.onCompleted: canvasSurface.visible=false }
        Frame { id:frameView; anchors.fill:parent; screen:outputA }
        readonly property alias frame: frameView
        property int windowChanges:0
        property int fullscreenChanges:0
        property int reservationChanges:0
        Connections { target:ServiceCompositor; function onWindowListChanged() { window.windowChanges++; } }
        Connections { target:ServiceCompositor; function onFullscreenOutputsChanged() { window.fullscreenChanges++; } }
        Connections { target:frameView; function onReservationsChanged() { window.reservationChanges++; } }
        function check(ok,message) { if(!ok) throw new Error(message); }
        function send(event) { ServiceCompositor.backend.event(JSON.stringify(event)); }
        function tile(width,height,x=null,y=null) { return {tile_size:[width,height],tile_pos_in_workspace_view:x===null || y===null ? null : [x,y],window_size:[width,height]}; }
        function fullscreen(on) { send({WindowLayoutsChanged:{changes:[[1,on ? tile(1280,800) : tile(1000,700,10,10)]]}}); }
        function find(item,name) { if(item.objectName===name) return item; for(const child of item.children || []) { const match=find(child,name); if(match) return match; } return null; }
        TestCase {
            id: input; when:false; optional:true
            function edge(side) {
                if(side===Enums.EdgeTop) mouseMove(window.contentItem,640,1);
                else if(side===Enums.EdgeBottom) mouseMove(window.contentItem,640,799);
                else if(side===Enums.EdgeLeft) mouseMove(window.contentItem,1,400);
                else mouseMove(window.contentItem,1279,400);
            }
            function outside() { mouseMove(window.contentItem,640,400); }
            function until(test,message,timeout=1200) {
                let elapsed=0;
                while(!test() && elapsed<timeout) { wait(20); elapsed+=20; }
                window.check(test(),message);
            }
            function exercise() {
                until(()=>Config.initialized,"Settings did not initialize",2000);
                Config.set("barScreens",["A"]); Config.set("dockScreens",["A"]);
                until(()=>Config.initialized && window.frame && window.frame.bar && window.frame.dock,"Frame did not initialize",2000);
                const frame=window.frame, check=window.check;
                const send=event=>window.send(event), tile=(...args)=>window.tile(...args), fullscreen=on=>window.fullscreen(on), find=(...args)=>window.find(...args);
                Config.set("barHideAuto",false); Config.set("dockHideAuto",false);
                Config.set("barHideSmart",true); Config.set("dockHideSmart",true);
                ServiceCompositor.backend.testOutputs=[outputA,outputB];
                send({CastsChanged:{casts:[{stream_id:1,session_id:10,is_active:true,target:{Output:{name:"A"}}},{stream_id:2,session_id:10,is_active:false,target:{Window:{id:2}}}]}});
                check(ServiceCompositor.captureStreams.length===2 && ServiceRecording.streams.length===1 && ServiceRecording.outputs[0]==="A", "Cast snapshot was not normalized");
                send({CastStartedOrChanged:{cast:{stream_id:1,session_id:10,is_active:false,target:{Output:{name:"A"}}}}});
                check(ServiceCompositor.captureStreams.length===2 && !ServiceRecording.active,"Pausing a cast duplicated it or kept its indicator active");
                send({CastStartedOrChanged:{cast:{stream_id:2,session_id:10,is_active:true,target:{Window:{id:2}}}}});
                check(ServiceRecording.active && ServiceRecording.streams[0].windowId===2,"Resuming a window cast failed");
                send({CastStopped:{stream_id:2}});
                check(!ServiceRecording.active && ServiceCompositor.captureStreams.length===1,"Stopped cast left stale capture state");
                send({CastsChanged:{casts:[]}});
                send({WorkspacesChanged:{workspaces:[
                    {id:10,idx:1,output:"A",is_active:true,is_focused:true,active_window_id:1},
                    {id:11,idx:2,output:"A",is_active:false,is_focused:false,active_window_id:3},
                    {id:12,idx:3,output:"A",is_active:false,is_focused:false,active_window_id:null},
                    {id:20,idx:1,output:"B",is_active:true,is_focused:false,active_window_id:2},
                    {id:21,idx:2,output:"B",is_active:false,is_focused:false,active_window_id:null}
                ]}});
                send({WindowsChanged:{windows:[
                    {id:1,workspace_id:10,app_id:"surface-test",is_focused:true,layout:tile(1000,700,10,10)},
                    {id:2,workspace_id:20,layout:tile(1920,1080)},
                    {id:3,workspace_id:11,layout:tile(1280,800)}
                ]}});
                check(ServiceCompositor.fullscreenOutputs.join(",")==="B","Inactive workspace affected fullscreen outputs");
                check(!frame.fullscreen && frame.bar.revealWanted && frame.dock.revealWanted,"Other output changed normal panels");
                check(layout.canvasSurface.surfaceLayer===WlrLayer.Overlay,"Shell canvas does not sit above fullscreen apps");
                Config.set("barHideAuto",true); Config.set("dockHideAuto",true); outside(); wait(30);
                check(!frame.bar.revealWanted && !frame.dock.revealWanted,"Occupied output should auto-hide its panels");
                send({WorkspaceActivated:{id:21,focused:true}}); wait(30);
                check(ServiceCompositor.workspaceEmptyOnOutput("B") && !ServiceCompositor.workspaceEmptyOnOutput("A"),"Empty workspace state leaked between outputs");
                check(!frame.bar.revealWanted && !frame.dock.revealWanted,"Focusing another output's empty workspace revealed these panels");
                until(()=>!frame.bar.revealed && !frame.dock.revealed,"Other output's empty workspace kept panels visible");
                send({WorkspaceActivated:{id:12,focused:true}}); wait(30);
                check(frame.bar.revealWanted && frame.dock.revealWanted,"Own empty workspace did not reveal panels");
                send({WindowOpenedOrChanged:{window:{id:4,workspace_id:12,is_floating:true}}}); wait(30);
                check(!frame.bar.revealWanted && !frame.dock.revealWanted,"Floating window left its workspace marked empty");
                send({WindowClosed:{id:4}}); wait(30);
                check(frame.bar.revealWanted && frame.dock.revealWanted,"Closing the last window did not reveal its panels");
                Config.set("barHideSmart",false); Config.set("dockHideSmart",false); wait(30);
                check(!frame.bar.revealWanted && !frame.dock.revealWanted,"Disabled empty-workspace setting revealed panels");
                check(!ServiceCompositor.workspaceEmptyOnOutput("missing"),"Unknown output was treated as empty");
                Config.set("barHideSmart",true); Config.set("dockHideSmart",true);
                send({WorkspaceActivated:{id:10,focused:true}}); send({WorkspaceActivated:{id:20,focused:false}}); wait(30);
                check(!frame.bar.revealWanted && !frame.dock.revealWanted,"Returning to an occupied workspace left panels revealed");
                Config.set("barHideAuto",false); Config.set("dockHideAuto",false);
                fullscreen(true); wait(30);
                check(frame.fullscreen && ServiceCompositor.fullscreenOutputs.join(",")==="A,B","Live layout event did not enter fullscreen");
                ServiceNotifications.setDnd(true,30);
                send({CastStartedOrChanged:{cast:{stream_id:3,session_id:20,is_active:true,target:{Output:{name:"A"}}}}}); wait(40);
                const mark=window.find(frame.island,"recordingMark"), island=window.find(frame.island,"dynamicIsland");
                check(mark && mark.visible && island.active && island.shown.kind==="recording","Fullscreen or DND hid the recording indicator");
                check(island.recording && island.implicitWidth===10 && island.implicitHeight===10,"Recording expands the island instead of showing only a dot");
                check(frame.island.bodyRect.width===0 && frame.island.bodyRect.height===0,"Recording dot keeps the island background");
                check(!window.find(island,"islandTitle").visible && !window.find(island,"islandBody").visible,"Recording dot keeps its title or details");
                check(window.find(island,"islandCompactContent").acceptedButtons===Qt.NoButton,"Recording status opens an unrelated media menu");
                for (const side of [Enums.EdgeTop,Enums.EdgeBottom,Enums.EdgeLeft,Enums.EdgeRight]) {
                    Config.set("barSide",side); wait(30);
                    check(mark.visible && mark.width===10 && mark.height===10,"Recording dot changes size with bar position");
                    const point=mark.mapToItem(frame,mark.width/2,mark.height/2);
                    check(side<2 ? Math.abs(point.x-frame.width/2)<0.5 : Math.abs(point.y-frame.height/2)<0.5,"Recording dot is not centered on its edge");
                    check(frame.island.bodyRect.width===0 && frame.island.bodyRect.height===0,"Moving the bar restores a recording island background");
                }
                Config.set("barSide",Enums.EdgeTop); wait(30);
                island.toggleMenu(); wait(60);
                const mediaMark=window.find(frame.island,"mediaRecordingIndicator");
                check(mediaMark && mediaMark.visible,"Expanded island media menu hid the recording indicator");
                MenuState.close(); wait(40);
                send({CastStopped:{stream_id:3}}); ServiceNotifications.setDnd(false); wait(30);
                check(!ServiceRecording.active && !mark.visible,"Recording indicator stayed visible after capture stopped");
                check(frame.island.bodyRect.width===0 && frame.island.bodyRect.height===0,"Stopping capture flashes an island background");
                const fullscreenState=ServiceCompositor.fullscreenOutputs, fullscreenChanges=window.fullscreenChanges;
                for(let i=0;i<40;i++) {
                    const record=ServiceCompositor.windowList.find(window=>window.id===1);
                    send({WindowOpenedOrChanged:{window:Object.assign({},record,{title:"Changed " + i})}});
                }
                check(ServiceCompositor.fullscreenOutputs===fullscreenState && window.fullscreenChanges===fullscreenChanges,"Title changes republished fullscreen state");
                const count=window.windowChanges;
                fullscreen(true); check(window.windowChanges===count,"Geometry updates rebuilt application lists");
                check(frame.reservations.every(value=>value>=Theme.frameThickness),"Fullscreen changed the normal work area");
                send({WindowFocusChanged:{id:null}}); check(frame.fullscreen,"Opening a shell surface cleared fullscreen detection");
                send({WorkspaceActiveWindowChanged:{workspace_id:10,active_window_id:null}}); check(!frame.fullscreen,"No active window retained fullscreen");
                send({WorkspaceActiveWindowChanged:{workspace_id:10,active_window_id:1}}); check(frame.fullscreen,"Restoring active window did not restore fullscreen");
                send({OverviewOpenedOrClosed:{is_open:true}}); check(!frame.fullscreen,"Overview did not restore panels");
                send({OverviewOpenedOrClosed:{is_open:false}}); check(frame.fullscreen,"Closing overview lost fullscreen state");
                fullscreen(false); wait(30);
                for(const mode of [0,1,2]) {
                    Config.set("themeAnimations",mode);
                    for(const side of [0,1,2,3]) {
                        Config.set("barSide",side); Config.set("dockSide",(side+1)%4);
                        until(()=>frame.frameReveal===1,"Normal frame did not finish revealing");
                        const reserved = JSON.stringify(frame.reservations), layoutReserved = JSON.stringify(layout.reservations);
                        const changesBefore = window.reservationChanges;
                        outside(); fullscreen(true); wait(30);
                        check(frame.bar.autoHide && frame.dock.autoHide,"Fullscreen did not override panel auto-hide settings");
                        until(()=>!frame.bar.revealed && !frame.dock.revealed,"Fullscreen panels did not hide at mode/side " + mode + "/" + side,1800);
                        until(()=>frame.bar.reveal===0 && frame.dock.container.reveal===0 && frame.thickness===0,"Fullscreen animation did not settle",1800);
                        check(JSON.stringify(frame.reservations)===reserved && JSON.stringify(layout.reservations)===layoutReserved && window.reservationChanges===changesBefore,"Fullscreen hide changed reserved space during animation at mode/side " + mode + "/" + side);
                        check(!frame.inputRegion.regions.includes(frame.bar.inputRegion) && !frame.inputRegion.regions.includes(frame.dock.inputRegion),"Hidden fullscreen panels intercepted application input");
                        check(!frame.island || frame.inputRegion.regions.includes(frame.island.inputRegion),"Fullscreen removed dynamic island input");
                        edge(side); wait(40);
                        check(!frame.bar.revealWanted && !frame.bar.revealed && frame.bar.reveal===0,"Edge hover revealed the fullscreen bar");
                        outside();
                        SidebarState.toggle("left","A"); wait(40);
                        check(!frame.bar.revealWanted,"Sidebar revealed the fullscreen bar"); SidebarState.close();
                        edge((side+1)%4); wait(40);
                        check(!frame.dock.revealWanted && !frame.dock.revealed && frame.dock.container.reveal===0,"Edge hover revealed the fullscreen dock");
                        fullscreen(false); wait(30);
                        check(frame.bar.revealWanted && frame.dock.revealWanted && !frame.bar.autoHide && !frame.dock.autoHide,"Fullscreen exit changed configured panel behavior");
                        until(()=>frame.frameReveal===1,"Restored frame did not finish revealing");
                        check(JSON.stringify(frame.reservations)===reserved && JSON.stringify(layout.reservations)===layoutReserved && window.reservationChanges===changesBefore,"Fullscreen exit resized the work area during animation at mode/side " + mode + "/" + side);
                        Config.set("barHideAuto",true); Config.set("dockHideAuto",true);
                        outside();
                        until(()=>!frame.bar.revealed && !frame.dock.revealed,"Normal auto-hide did not resume",1800);
                        until(()=>frame.bar.reveal===0 && frame.dock.container.reveal===0,"Normal hide animation did not settle",1800);
                        edge(side); wait(40);
                        check(frame.bar.revealed,"Normal bar hover reveal stopped working");
                        if(mode>0) check(frame.bar.reveal>0 && frame.bar.reveal<1,"Normal bar snapped instead of animating");
                        until(()=>frame.bar.reveal===1,"Normal bar reveal did not finish");
                        outside(); SidebarState.toggle("left","A"); wait(40);
                        check(frame.bar.revealWanted,"Sidebar did not hold the normal bar open"); SidebarState.close();
                        edge((side+1)%4); wait(40);
                        check(frame.dock.revealed,"Normal dock hover reveal stopped working");
                        until(()=>frame.dock.container.reveal===1,"Normal dock reveal did not finish");
                        const dockItem=frame.dock.container.children.find(child=>child.itemAtIndex!==undefined).itemAtIndex(0).item;
                        frame.dock.menuOpen(dockItem); outside(); wait(40);
                        check(frame.dock.revealWanted,"Dock menu did not hold the normal dock open");
                        const dockMenu=find(frame.dock,"dockPopupReveal");
                        check(dockMenu && dockMenu.width>0 && dockMenu.height>0,"Dock context menu has no surface");
                        if(mode===0) check(dockMenu.revealWidth===dockMenu.width && dockMenu.revealHeight===dockMenu.height,"Disabled dock menu animation retained a partial size");
                        else check(dockMenu.amount>0 && dockMenu.amount<1 && dockMenu.revealWidth<dockMenu.width && dockMenu.revealHeight<dockMenu.height,"Dock context menu does not expand in both dimensions");
                        const dockSide=Config.dockSide;
                        check(dockMenu.anchorX===(dockSide===Enums.EdgeLeft?0:dockSide===Enums.EdgeRight?1:0.5) && dockMenu.anchorY===(dockSide===Enums.EdgeTop?0:dockSide===Enums.EdgeBottom?1:0.5),"Dock menu expands away from the wrong edge");
                        fullscreen(true); wait(40);
                        check(!frame.bar.revealWanted && !frame.dock.revealWanted && !frame.dock.keyboardWanted,"Entering fullscreen retained the dock menu");
                        Config.set("barHideAuto",false); Config.set("dockHideAuto",false);
                        fullscreen(false); wait(30);
                        check(frame.bar.revealWanted && frame.dock.revealWanted && !frame.bar.autoHide && !frame.dock.autoHide,"Fullscreen exit changed configured panel behavior");
                    }
                }
                Config.set("themeAnimations",0);
                send({WindowFocusChanged:{id:1}}); wait(30);
                const dockRepeater=frame.dock.container.children.find(child=>child.itemAtIndex!==undefined);
                const dockItem=Array.from({length:dockRepeater.count},(_,index)=>dockRepeater.itemAtIndex(index).item)
                    .find(item=>item?.appId?.startsWith("surface-test") && item.windowCount>0);
                check(dockItem,"Running application is missing from the dock");
                frame.dock.menuOpen(dockItem); wait(40);
                const row=find(frame.dock,"dockWindowRow"), closeButton=find(frame.dock,"dockWindowClose");
                check(row && !row.filled && !row.selected && row.trailingIcon===Icon.check && row.height===36 && closeButton,
                    "Dock window list did not use the plain context-menu row with a focus check");
                const backend=ServiceCompositor.backend;
                backend.testActions=[];
                mouseClick(row,20,row.height/2,Qt.MiddleButton);
                check(backend.testActions[0]?.name==="CloseWindow" && backend.testActions[0].id===1 && frame.dock.keyboardWanted,
                    "Middle-click did not close the window while keeping the popup open");
                mouseMove(row,20,row.height/2); wait(20);
                check(closeButton.enabled,"Close action was not enabled on hover");
                mouseClick(closeButton,closeButton.width/2,closeButton.height/2,Qt.LeftButton);
                check(backend.testActions[1]?.name==="CloseWindow" && backend.testActions[1].id===1,
                    "Clicking the close action did not close the window");
                mouseClick(row,20,row.height/2,Qt.LeftButton);
                check(backend.testActions[2]?.name==="FocusWindow" && backend.testActions[2].id===1 && !frame.dock.keyboardWanted,
                    "Clicking the window row did not focus the window and dismiss the popup");

                const fake=ServiceCompositor.windowLayouts;
                fullscreen(false); check(ServiceCompositor.windowLayouts===fake,"Identical layout events allocate state");
                send({WindowClosed:{id:2}}); check(!ServiceCompositor.fullscreenOnOutput("B") && ServiceCompositor.windowLayouts[2]===undefined,"Closing fullscreen window left stale output state");
                console.log("SURFACES_PASSED per-output empty-workspace reveal, fullscreen suppresses panel hover and input on all edges/modes, island input preserved, normal smooth reveal, menu holds, margins and recovery");
            }
        }
        Timer { interval:100; running:true; onTriggered: { try { input.exercise(); } catch(error) { console.error("SURFACES_FAILED fullscreen",error); } Qt.quit(); } }
    }
}
''')


def island_transition_fixture(base):
    service = base / "modules/services/ServiceIsland.qml"
    service.write_text(service.read_text().replace("id: island", 'id: island\n    property var testScreens: [{name:"A"},{name:"B"}]', 1)
                       .replace("primaryOutputFor(Quickshell.screens, Config.barScreens)", "primaryOutputFor(testScreens, Config.barScreens)"))
    (base / "modules/services/ServiceRecording.qml").write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property bool active:false; property string detail:"Capture fixture"; }')
    (base / "shell.qml").write_text(r'''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/frame"

ShellRoot {
    Window {
        id: window; visible:true; width:1280; height:720
        QtObject {id:outputA;property string name:"A"}
        QtObject {id:outputB;property string name:"B"}
        Frame {id:first;screen:outputA;width:640;height:720}
        Frame {id:second;screen:outputB;x:640;width:640;height:720}
        function check(ok,message) {if(!ok)throw new Error(message);}
        function find(item,name) {
            if(item.objectName===name)return item;
            for(const child of item.children||[]){const result=find(child,name);if(result)return result;}
            return null;
        }
        TestCase {
            id:input;when:false;optional:true
            function showValue() {ServiceOSD.show("volume",Icon.volume,"Volume 72%",0.72,false,true,"","",10000);}
            function until(test,message,timeout=1800) {
                let elapsed=0;
                while(!test()&&elapsed<timeout){wait(20);elapsed+=20;}
                window.check(test(),message);
            }
            function exercise() {
                const check=window.check,find=window.find;
                until(()=>Config.initialized&&ServiceCompositor.backend,"Configuration did not load");
                Config.set("barEnabled",false);Config.set("dockEnabled",false);
                Config.set("barScreens",["A"]);Config.set("islandEnabled",true);
                ServiceCompositor.backend.focusedOutput="B";
                until(()=>first.island!==null&&second.island===null,"Island is not restricted to primary");
                for(const mode of [0,1,2])for(const side of [0,1,2,3]) {
                    Config.set("themeAnimations",mode);Config.set("barSide",side);
                    ServiceRecording.active=true;
                    const island=first.island,widget=find(island,"dynamicIsland"),dot=find(island,"recordingMark");
                    until(()=>dot.opacity>0.99&&island.expansionProgress===0,"Recording dot did not settle");
                    check(island.bodyRect.width===0&&island.bodyRect.height===0,"Recording has an island background");
                    check(island.inputRegion.regions[0].item===null,"Recording dot captures input");
                    Config.set("islandRecordingIndicator",false);
                    until(()=>!dot.visible&&!widget.active,"Disabling indication kept the recording dot visible");
                    check(ServiceRecording.active&&island.bodyRect.width===0,"Indicator toggle changed recording or left an empty background");
                    Config.set("islandRecordingIndicator",true);
                    until(()=>dot.opacity>0.99,"Re-enabling indication did not restore the recording dot");
                    showValue();wait(mode?120:10);
                    check(widget.shown.kind==="osd"&&second.island===null,"Secondary-focus value event missed primary");
                    if(mode) {
                        check(island.expansionProgress>0&&island.expansionProgress<1,"Dot-to-island transition snaps");
                        check(dot.opacity>0&&dot.opacity<1&&island.bodyRect.width>10,"Dot does not blend into the growing island");
                        check(find(widget,"islandCompactContent").opacity<1,"Content appears before its surface expands");
                    }
                    until(()=>island.expansionProgress>0.999,"Expanded island did not settle");
                    check(!dot.visible,"Expanded island duplicates the standalone capture dot");
                    ServiceOSD.hide();wait(mode?120:10);
                    check(widget.recording,"Recording did not return after OSD");
                    if(mode)check(island.expansionProgress>0&&island.expansionProgress<1&&dot.opacity>0&&dot.opacity<1,"Island-to-dot transition snaps: mode "+mode+", edge "+side+", expansion "+island.expansionProgress+", dot "+dot.opacity);
                    until(()=>island.expansionProgress===0,"Recording island did not finish collapsing");
                    check(dot.visible&&island.bodyRect.width===0,"Collapsed capture is not a lone dot");
                    if(mode===2&&side===0) {
                        showValue();wait(120);ServiceOSD.hide();wait(35);showValue();
                        until(()=>widget.shown.kind==="osd"&&island.expansionProgress>0.999,"Interrupted morph did not recover");
                        ServiceOSD.hide();until(()=>island.expansionProgress===0,"Interrupted morph left a background");
                        showValue();wait(120);Config.set("themeAnimations",0);wait(0);
                        check(island.expansionProgress===1&&!dot.visible,"Disabling animations leaves a partial morph");
                        ServiceOSD.hide();wait(0);
                        check(island.expansionProgress===0,"Disabled animations leave a recording background");
                    }
                    ServiceRecording.active=false;
                    until(()=>!dot.visible,"Stopped capture keeps its dot");
                    check(island.bodyRect.width===0,"Stopped capture flashes a background");
                }
                Config.set("themeAnimations",0);ServiceRecording.active=true;wait(20);
                const widget=find(first.island,"dynamicIsland");
                widget.toggleMenu();wait(30);check(MenuState.menuActive,"Media menu fixture did not open");
                Config.set("barScreens",["B"]);wait(30);
                check(first.island===null&&second.island!==null&&!MenuState.menuActive,"Changing primary duplicates the island or leaves its menu");
                check(find(second.island,"recordingMark").visible,"Changing primary loses the capture dot");
                Config.set("barScreens",["A"]);ServiceIsland.testScreens=[{name:"B"}];wait(30);
                check(first.island===null&&second.island!==null,"Disconnected primary has no live fallback");
                ServiceIsland.testScreens=[{name:"A"},{name:"B"}];wait(30);
                check(first.island!==null&&second.island===null,"Reconnecting primary does not restore the island");
                ServiceLock.locked=true;wait(10);
                check(!find(first.island,"recordingMark").visible,"Recording dot leaks through lock screen");
                console.log("SURFACES_PASSED primary-only island, secondary-focus events, hotplug, menu cleanup, dot morphs on all edges and animation modes, interruption and locking");Qt.quit();
            }
        }
        Timer {interval:180;running:Config.initialized;onTriggered:{try{input.exercise();}catch(error){console.error("SURFACES_FAILED",error);Qt.quit();}}}
    }
}
''')


def artwork_checks():
    import runpy

    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-artwork-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        (base / "home").mkdir()
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"))
        env.pop("WAYLAND_DISPLAY", None)
        for name in ("first.png", "second.png", "third.png"):
            shutil.copyfile(base / "fixture.png", base / name)
        media = base / "modules/services/ServiceMedia.qml"
        media.write_text(media.read_text().replace("readonly property var players: Mpris.players.values", "property var players: []"))
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/bar/menus"

ShellRoot {
    QtObject {
        id: player
        property string dbusName: "artwork-test"
        property string identity: "Player"
        property string trackTitle: "Track"
        property string trackArtist: "Artist"
        property string trackAlbum: "Album"
        property string trackArtUrl: ""
        property bool isPlaying: false
        property bool positionSupported: false
        property bool lengthSupported: false
        property bool canSeek: false
        property bool canTogglePlaying: false
        property bool canGoPrevious: false
        property bool canGoNext: false
        property bool shuffleSupported: false
        property bool shuffle: false
        property bool loopSupported: false
        property int loopState: 0
    }
    Window {
        visible: true; width: 500; height: 400
        MenuMedia { id: menu; width: implicitWidth; height: implicitHeight }
        TestCase {
            id: input; when: false; optional: true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function settled(cover, url) {
                return cover.currentImage.status === Image.Ready
                    && String(cover.currentImage.source) === String(url) && cover.blend === 0;
            }
            function awaitState(predicate, message) {
                for (let i = 0; i < 100; i++) { if (predicate()) return; wait(20); }
                throw new Error(message);
            }
            function exercise() {
                ServiceMedia.players = [player];
                const cover = findChild(menu, "mediaArtwork");
                check(cover && menu.active, "Artwork is not visible");
                const first = Qt.resolvedUrl("first.png"), second = Qt.resolvedUrl("second.png"), third = Qt.resolvedUrl("third.png");
                for (const mode of [0, 1, 2]) {
                    Config.set("themeAnimations", mode);
                    player.trackArtUrl = first;
                    awaitState(() => settled(cover, first), "First artwork failed to load");
                    const previous = cover.currentImage;
                    player.trackArtUrl = second;
                    if (mode > 0) {
                        awaitState(() => cover.blend > 0 && cover.blend < 1, "Artwork did not crossfade");
                        check(cover.currentImage === previous && previous.opacity === 1, "Outgoing artwork disappeared during the crossfade");
                    }
                    player.trackArtUrl = third;
                    awaitState(() => settled(cover, third), "Rapid artwork changes did not show the latest cover");
                    player.trackArtUrl = "";
                    awaitState(() => cover.currentImage.status === Image.Null && cover.blend === 0, "Missing artwork left a stale cover");
                    player.trackArtUrl = Qt.resolvedUrl("missing.png");
                    awaitState(() => cover.currentImage.status === Image.Error && cover.blend === 0, "Failed artwork left a transition running");
                    player.trackArtUrl = first;
                    awaitState(() => settled(cover, first), "Artwork did not recover after an error");
                    player.trackArtUrl = second;
                    wait(60);
                    Config.set("themeAnimations", 0);
                    awaitState(() => settled(cover, second), "Disabling animations left artwork between covers");
                }
                ServiceMedia.players = [];
                console.log("ARTWORK_PASSED loading, crossfades, rapid changes, missing/failed artwork, recovery, and animation cancellation");
                Qt.quit();
            }
        }
        Timer {
            interval: 150; running: Config.initialized
            onTriggered: { try { input.exercise(); } catch (error) { console.error("ARTWORK_FAILED", error); Qt.quit(); } }
        }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "ARTWORK_PASSED" in output, output
        assert not re.search(r"ARTWORK_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


def main():
    check_sources()
    with tempfile.TemporaryDirectory(prefix="bloodyshell-surfaces-") as temporary:
        run_fixture(Path(temporary))
    with tempfile.TemporaryDirectory(prefix="bloodyshell-audio-dropdown-") as temporary:
        run_fixture(Path(temporary), audio_dropdown_fixture)
    with tempfile.TemporaryDirectory(prefix="bloodyshell-fullscreen-") as temporary:
        run_fixture(Path(temporary), fullscreen_fixture)
    with tempfile.TemporaryDirectory(prefix="bloodyshell-island-transitions-") as temporary:
        run_fixture(Path(temporary), island_transition_fixture)
    artwork_checks()
    print("Three surface hosts, frame styles, dock joins, sidebars, dynamic overlays, and island presentation passed.")


if __name__ == "__main__":
    main()
