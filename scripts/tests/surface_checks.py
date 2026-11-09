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
    assert sorted(hosts) == ["modules/ui/desktop/Desktop.qml", "modules/ui/layout/Layout.qml", "modules/ui/overlay/Overlay.qml"], hosts


def run_fixture(base):
    shutil.copytree(ROOT / "modules", base / "modules")
    (base / "assets").symlink_to(ROOT / "assets", target_is_directory=True)
    (base / "translations").symlink_to(ROOT / "translations", target_is_directory=True)
    shutil.copytree(ROOT / "scripts", base / "scripts", ignore=shutil.ignore_patterns("tests", "tools", "__pycache__"))
    shutil.copy2(ROOT / "setup", base / "setup")
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
    source = (base / "modules/ui/overlay/Overlay.qml").read_text().replace("PanelWindow\n{", "Item\n{", 1)
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
    layout = re.sub(r"^        WlrLayershell.keyboardFocus:[^\n]*\n(?: +:[^\n]*\n)*", "", layout, flags=re.M)
    layout = re.sub(r"^        (?:WlrLayershell\.|BackgroundEffect\.).*\n", "", layout, flags=re.M)
    (base / "modules/ui/layout/LayoutFixture.qml").write_text(layout)
    (base / "modules/ui/layout/FakePanelWindow.qml").write_text('''import QtQuick
import Quickshell
Item
{
    property var screen
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
    function check(ok, message) { if (!ok) throw new Error(message) }
    function ready(name)
    {
        check(overlay.testPage.status === Loader.Ready && overlay.testPage.item.name === name, "Could not load " + name);
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
        for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
        return null;
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
            const panel = (side === "left" ? frame.leftSidebar : frame.rightSidebar).panel;
            const gap = Theme.frameSmoothing;
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
                model: ["Battery", "Bluetooth", "Clock", "Layout", "Media", "Network", "Notifications", "Tray", "Volume"]
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
            MenuToggle { id: rowProbe; text: "Shared switch"; onToggle: value => checked = value }
            ControlToggle { id: tileProbe; width: parent.width; height: implicitHeight; text: "Wi-Fi"; onToggled: value => checked = value }
            ControlSlider
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
        property int previewStep: 0
        property int previewWait: 0
        property real previewPhase: 0
        property real previewBarHeight: 0
        property int mediaChecks: 0
        property int sidebarChecks: 0
        interval: 80; repeat: true; running: true
        onTriggered:
        {
            if (!Config.initialized) return;
            try
            {
                if (step < 32)
                {
                    if (step > 0) { tests.geometry(); tests.barInteraction(); }
                    else
                    {
                        ServiceCompositor.windowList = [{id:1,app_id:"test",title:"A window title"}];
                        ServiceCompositor.lastWindowId = 1;
                        ServiceCompositor.focusedWindowId = 1;
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
                        ServiceCompositor.windowList = [{id:1,app_id:"one",title:"One"},{id:2,app_id:"two",title:"Two"}];
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
                    case 12: tests.ready("helper"); OverlayState.show("wallpapers"); break;
                    case 13: tests.ready("wallpapers"); OverlayState.show("power"); break;
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
                        tests.check(frame.leftSidebar.opened && frame.surface.leftBody.width > 0 && frame.keyboardWanted, "Left sidebar did not join the frame");
                        frame.leftSidebar.open("settings"); break;
                    case 22:
                        tests.ready("settings"); tests.check(!SidebarState.active, "Sidebar survived opening settings");
                        OverlayState.close(); SidebarState.toggle("right", Quickshell.screens[0].name); break;
                    case 23:
                        tests.check(frame.rightSidebar.opened && frame.surface.rightBody.width > 0, "Right sidebar did not join the frame");
                        SidebarState.toggle("right", "other-output"); break;
                    case 24:
                        tests.check(!frame.sidebarHere && frame.surface.rightBody.width === 0, "Sidebar appeared on the wrong output");
                        SidebarState.toggle("right", Quickshell.screens[0].name); break;
                    case 25: overlay.testAgent.isActive = true; break;
                    case 26:
                        tests.check(!SidebarState.active, "Authentication did not close the sidebar");
                        overlay.testAgent.isActive = false;
                        tests.check(Registry.widgets.system === undefined && Registry.widgets.user === undefined, "System widget was retained");
                        const notificationsWidget = tests.find(frame.bar, "notificationsWidget");
                        tests.check(notificationsWidget !== null, "Notification widget is missing");
                        const clockSlot = tests.slot(frame.bar, "clock"), notificationsSlot = tests.slot(frame.bar, "notifications");
                        tests.check(frame.bar.isHorizontal ? notificationsSlot.x > clockSlot.x : notificationsSlot.y > clockSlot.y, "Notifications are not after the clock");
                        ServiceNotifications.unreadCounter = 3;
                        events.mouseClick(notificationsWidget, notificationsWidget.width / 2, notificationsWidget.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(MenuState.menuWidget === notificationsWidget && !SidebarState.active && !OverlayState.active && ServiceNotifications.unreadCounter === 0,
                            "Notification widget did not open its own menu and mark history read");
                        ServiceMedia.players = [player]; break;
                    case 27:
                        tests.check(tests.find(frame.bar, "notificationsMenu") !== null, "Notification history did not load in the bar menu");
                        MenuState.close();
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
                        tests.check(tests.find(frame.rightSidebar, "controlVolume").height === 36 && tests.find(frame.rightSidebar, "controlMicrophone").height === 36 && tests.find(frame.rightSidebar, "controlBrightness").height === 36, "Control center sliders are not compact");
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
                        player.isPlaying = false; player.trackTitle = ""; ServiceMedia.players = []; break;
                    case 36:
                        tests.check(MenuState.menuActive && MenuState.menuOwner === tests.mediaOwner && tests.find(frame.island, "dynamicIsland") === tests.mediaWidget, "Track loading closed or recreated the menu");
                        player.trackTitle = "Next track"; player.isPlaying = true; ServiceMedia.players = [player]; break;
                    case 37:
                        tests.check(MenuState.menuActive && tests.mediaWidget.shown.title === "Next track", "Track update lost the media menu");
                        MenuState.close(); player.isPlaying = false;
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
                        const defaultMenu = tests.find(overlay.testPage.item, "menuStyle-" + Enums.MenuDefault);
                        const floatingMenu = tests.find(overlay.testPage.item, "menuStyle-" + Enums.MenuFloating);
                        tests.check(defaultMenu && floatingMenu && defaultMenu.kind === "menu" && floatingMenu.width <= 150, "Compact menu preview cards failed to load");
                        tests.check(defaultMenu.label === Tr.tr("common.default"), "Default menu label was not renamed");
                        floatingMenu.clicked(); OverlayState.close();
                        SidebarState.toggle("left", Quickshell.screens[0].name); break;
                    case 44:
                        tests.check(Config.barMenu === Enums.MenuFloating && frame.leftSidebar.floating, "Sidebar ignores the menu style");
                        tests.check(frame.leftSidebar.panel.x > Theme.frameThickness && frame.surface.leftBody.width === 0, "Floating sidebar still participates in the frame shader");
                        tests.check(frame.leftSidebar.panel.children.some(item => item.visible && item.color !== undefined && item.radius === Theme.barRadius), "Floating sidebar lost its separate background");
                        SidebarState.toggle("right", Quickshell.screens[0].name); break;
                    case 45:
                        tests.check(frame.rightSidebar.panel.x + frame.rightSidebar.panel.width < frame.width - Theme.frameThickness, "Right floating sidebar has no edge gap");
                        tests.check(frame.surface.rightBody.width === 0, "Right floating sidebar still participates in the frame shader");
                        Config.set("barMenu", Enums.MenuDefault); break;
                    case 46:
                        tests.check(!frame.rightSidebar.floating && frame.rightSidebar.opened, "Changing the menu style dismissed the sidebar");
                        tests.check(frame.rightSidebar.panel.x + frame.rightSidebar.panel.width === frame.width - Theme.frameThickness && frame.surface.rightBody.width > 0, "Default sidebar no longer joins the frame");
                        ServiceCompositor.lastWindowId = 1; ServiceCompositor.focusedWindowId = null;
                        const clockAfterSidebar = tests.slot(frame.bar, "clock");
                        events.mouseClick(clockAfterSidebar, clockAfterSidebar.width / 2, clockAfterSidebar.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(!SidebarState.active && MenuState.menuActive, "Opening a menu did not replace the sidebar");
                        ServiceCompositor.focusedWindowId = 1;
                        tests.check(MenuState.menuActive, "Restoring focus after a sidebar dismissed the new menu");
                        ServiceCompositor.focusedWindowId = 2;
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
                        Config.set("barMenu", Enums.MenuFloating);
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
                        events.mouseClick(rowProbe, 20, rowProbe.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(rowProbe.checked, "Shared menu row no longer toggles");
                        const switchControl = rowProbe.children.find(item => item.thumbStretch !== undefined);
                        tests.check(switchControl !== undefined, "Menu row does not use the shared switch");
                        events.mouseMove(switchControl, switchControl.width / 2, switchControl.height / 2, 0);
                        tests.check(rowProbe.hovered, "Shared switch loses the row hover animation");
                        events.mouseClick(switchControl, switchControl.width / 2, switchControl.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(!rowProbe.checked, "Clicking the shared switch toggles twice");
                        events.mouseClick(tileProbe, tileProbe.width / 2, tileProbe.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(tileProbe.checked && String(tileProbe.children[0].color) === String(Theme.colorAccent), "Enabled control tile does not highlight its full background");
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
                        tests.check(frame.surface.startBody.width === 0 && frame.surface.endBody.width === 0 && frame.surface.dockBody.width === 0, "Islands bodies are included in the frame shader");
                        const capsules = tests.findAll(frame.bar, "barIslandSurface");
                        tests.check(capsules.length === 2 && capsules.every(item => item.visible && item.width > 0 && item.height > 0 && item.color === Theme.frameColor), "Bar groups have no independent capsule backgrounds");
                        for (const capsule of capsules)
                        {
                            const point = capsule.mapToItem(frame, 0, 0);
                            const gap = Config.barSide === Enums.EdgeTop ? point.y : Config.barSide === Enums.EdgeBottom ? frame.height - point.y - capsule.height
                                : Config.barSide === Enums.EdgeLeft ? point.x : frame.width - point.x - capsule.width;
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
                        tests.check(frame.dock.container.color === Theme.frameColor && tests.findAll(frame.bar, "barIslandSurface").every(item => item.color === Theme.frameColor), "Islands colors ignore the light theme");
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
                        tests.check(tests.findAll(frame.bar, "barIslandSurface").every(item => !item.visible), "Hidden bar left capsule backgrounds visible");
                        tests.check(frame.dock.container.x >= frame.width, "Hidden Islands dock left its background onscreen");
                        frame.bar.revealed = true; frame.dock.revealed = true;
                        OverlayState.settingsPage = 0; OverlayState.show("settings"); break;
                    default:
                        if (sidebarChecks === 0 && step - 32 >= 50 && step - 116 < Registry.settings.length)
                        {
                            tests.ready("settings");
                            tests.check(tests.loadedPage(overlay.testPage.item, Registry.settings[step - 116].page) !== null, "Settings page failed to load after relocation: " + Registry.settings[step - 116].id);
                            if (Registry.settings[step - 116].id === "appearance")
                            {
                                const wallpaperPreview = tests.find(overlay.testPage.item, "currentWallpaperPreview");
                                tests.check(wallpaperPreview && wallpaperPreview.wallpaper === Config.wallpaperCurrent && wallpaperPreview.height === 172, "Appearance lost its shared wallpaper preview");
                                const bars = tests.find(overlay.testPage.item, "equalizerStyle-" + Enums.EqualizerBars);
                                const waves = tests.find(overlay.testPage.item, "equalizerStyle-" + Enums.EqualizerWaves);
                                tests.check(bars && waves && waves.kind === "equalizer" && waves.width <= 150, "Equalizer style previews are missing");
                                const preview = tests.find(waves, "equalizerStylePreview");
                                if (previewStep === 0)
                                {
                                    tests.check(!Config.animationsEnabled, "Preview fixture must cover disabled shell animations");
                                    const page = tests.loadedPage(overlay.testPage.item, Registry.settings[step - 116].page);
                                    tests.check(tests.find(page, "currentWallpaperRow") !== null, "Wallpaper preview is outside a settings row");
                                    page.contentY = Math.max(0, Math.min(page.contentHeight - page.height, waves.mapToItem(page.contentItem, 0, 0).y - 120));
                                    events.mouseMove(waves, waves.width / 2, waves.height / 2, 0);
                                    previewPhase = preview.phase; previewStep++; return;
                                }
                                if (previewStep === 1)
                                {
                                    if (preview.phase === previewPhase && previewWait++ < 4) return;
                                    tests.check(waves.previewing && preview.phase !== previewPhase, "Waves hover preview did not animate with shell animations disabled");
                                    events.mouseMove(window.contentItem, 2, 2, 0);
                                    previewStep++; return;
                                }
                                if (previewStep === 2)
                                {
                                    tests.check(!waves.previewing, "Waves preview did not stop on hover leave");
                                    previewPhase = preview.phase; previewStep++; return;
                                }
                                if (previewStep === 3)
                                {
                                    tests.check(preview.phase === previewPhase, "Unhovered Waves preview keeps animating");
                                    window.requestActivate();
                                    waves.forceActiveFocus(Qt.TabFocusReason);
                                    previewPhase = preview.phase;
                                    previewStep++; return;
                                }
                                if (previewStep === 4)
                                {
                                    tests.check(waves.previewing && preview.phase !== previewPhase, "Keyboard focus did not animate the equalizer preview");
                                    waves.focus = false;
                                    events.mouseMove(bars, bars.width / 2, bars.height / 2, 0);
                                    previewBarHeight = tests.find(bars, "equalizerBar").height;
                                    previewStep++; return;
                                }
                                if (previewStep === 5)
                                {
                                    tests.check(bars.previewing, "Bars hover preview did not start");
                                    tests.check(Math.abs(tests.find(bars, "equalizerBar").height - previewBarHeight) > 0.05, "Bar heights remain frozen during hover");
                                    events.mouseMove(window.contentItem, 2, 2, 0);
                                    previewBarHeight = tests.find(bars, "equalizerBar").height;
                                    previewPhase = tests.find(bars, "equalizerStylePreview").phase;
                                    previewStep++; return;
                                }
                                if (previewStep === 6)
                                {
                                    tests.check(!bars.previewing && tests.find(bars, "equalizerBar").height === previewBarHeight, "Bars changed after hover ended");
                                    const barsPreview = tests.find(bars, "equalizerStylePreview");
                                    tests.check(barsPreview.phase === previewPhase, "Bars preview phase changed while idle");
                                    events.mouseMove(bars, bars.width / 2, bars.height / 2, 0);
                                    tests.check(barsPreview.phase >= previewPhase && barsPreview.phase - previewPhase < 0.2, "Hovering again reset the Bars preview phase");
                                    previewStep++; return;
                                }
                                if (previewStep === 7)
                                {
                                    tests.check(tests.find(bars, "equalizerStylePreview").phase > previewPhase, "Bars did not resume from their saved phase");
                                    tests.check(Math.abs(tests.find(bars, "equalizerBar").height - previewBarHeight) > 0.05, "Bars did not resume from their saved heights");
                                    events.mouseMove(window.contentItem, 2, 2, 0);
                                }
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
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
               XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
               PATH=str(base / "bin") + os.pathsep + os.environ["PATH"],
               DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-session-bus",
               DBUS_SYSTEM_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-system-bus", NIRI_SOCKET="/tmp/bloodyshell-test-no-niri")
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=20)
    print(result.stdout)
    assert result.returncode == 0 and "SURFACES_PASSED" in result.stdout, "Surface integration checks failed"
    assert not re.search(r"SURFACES_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", result.stdout), "Surface QML error"


def main():
    check_sources()
    with tempfile.TemporaryDirectory(prefix="bloodyshell-surfaces-") as temporary:
        run_fixture(Path(temporary))
    print("Three surface hosts, frame styles, dock joins, sidebars, dynamic overlays, and island presentation passed.")


if __name__ == "__main__":
    main()
