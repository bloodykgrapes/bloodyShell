#!/usr/bin/env python3

import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
helpers = runpy.run_path(str(ROOT / "scripts/tests/run.py"))
put, stub, module = (helpers[key] for key in ("put", "stub", "module"))

with tempfile.TemporaryDirectory(prefix="bloodyshell-menu-geometry-") as temporary:
    base = Path(temporary)
    for folder in ("core", "runtime", "cache"):
        (base / folder).mkdir(mode=0o700)
    shutil.copytree(ROOT / "modules/animations", base / "animations")
    (base / "common").mkdir()
    for name in ("Menu", "RevealSection", "RenderActivity"):
        shutil.copyfile(ROOT / f"modules/common/{name}.qml", base / f"common/{name}.qml")
    put(base, "common/FloatingPanelSurface.qml", 'import QtQuick\nItem { property real reveal: 1 }\n')
    (base / "ui/bar/components").mkdir(parents=True)
    for name in ("BarZone", "BarMenu", "MenuSlot", "WidgetRow", "WidgetSlot"):
        shutil.copyfile(ROOT / f"modules/ui/bar/components/{name}.qml", base / f"ui/bar/components/{name}.qml")
    shutil.copyfile(ROOT / "modules/core/Enums.qml", base / "core/Enums.qml")
    stub(base, "core", "Config", '''
    property bool debug: false
    property int mode: 0
    property int barSide: 0
    readonly property bool animationsEnabled: mode > 0
    readonly property bool animationsFluid: mode === 2
''')
    stub(base, "core", "Theme", '''
    property color frameColor: "#000000"
    property int panelBorderWidth: 1
    property color colorPanelEdge: "#29ffffff"
    property int barPadding: 8
    property int barThickness: 44
    property int barRadius: 22
    property int frameThickness: 8
    property int panelGap: 10
    property int barSpacing: 6
    property int barVerticalWidth: 44
    property int barGroupThickness: 32
    property int menuWidth: 320
    property int menuPadding: 10
    property int animationDurationMorph: 120
    property int animationDurationBar: 120
    function animationDuration(ms) { return ms }
    property var easingEmphasized: [0.16, 0.85, 0.2, 1.0, 1.0, 1.0]
''')
    stub(base, "core", "Registry", 'property var widgets: ({fixture:{url:Qt.resolvedUrl("../TestWidget.qml")}})')
    put(base, "TestWidget.qml", '''import QtQuick
Item
{
    property bool active: true
    property int side: 0
    property real along: 300
    implicitWidth: side < 2 ? along : 32
    implicitHeight: side < 2 ? 32 : along
}
''')
    stub(base, "core", "MenuState", '''
    property bool menuActive: false
    property var menuOwner: null
    property var menuWidget: null
    property string menuCurrent: ""
    function close() { menuActive = false }
''')
    module(base, "core")
    put(base, "ResizeMenu.qml", '''import QtQuick
import "common"
import "animations"
import "core"
Menu
{
    id: menu
    implicitWidth: 68
    implicitHeight: 68
    Glide on implicitHeight { enabled: menu.contentAnimatesHeight && Config.animationsEnabled }
    readonly property alias firstSection: first
    readonly property alias lastSection: last
    RevealSection { id: first; shown: menu.presented; order: 0; Item { width: parent.width; height: 16 } }
    RevealSection { id: last; shown: menu.presented; order: 6; Item { width: parent.width; height: 16 } }
}
''')
    put(base, "shell.qml", '''import QtQuick
import QtQuick.Window
import Quickshell
import "core"
import "ui/bar/components"

ShellRoot
{
    id: tests
    property int trial: -1
    property int phase: 0
    property real since: 0
    property var content: null
    property int samples: 0
    property var slot: null
    function verifyIsland()
    {
        const middle = zone.islandA0 + zone.islandAlong / 2;
        check(Math.abs(zone.anchorCenter - middle) <= 1, "Anchor left the resizing island center: " + zone.anchorCenter + " expected " + middle);
    }

    function check(ok, message) { if (!ok) throw new Error(message + " side=" + zone.side + " mode=" + Config.mode) }
    function nearEdge(rect)
    {
        switch (zone.side)
        {
            case Enums.EdgeTop: return rect.y;
            case Enums.EdgeBottom: return zone.height - rect.y - rect.height;
            case Enums.EdgeLeft: return rect.x;
            default: return zone.width - rect.x - rect.width;
        }
    }
    function verify(centered = false)
    {
        const edge = zone.baseOuter + (zone.attachedMenu ? 0 : Theme.panelGap);
        verifyAttachment();
        check(Math.abs(nearEdge(zone.panel.area) - edge) < 0.01, "Menu clip moved away from its edge during resize");
        const point = content.mapToItem(zone,
            zone.isHorizontal ? content.width / 2 : zone.isRight ? content.width : 0,
            zone.isHorizontal ? zone.isBottom ? content.height : 0 : content.height / 2);
        const distance = zone.isHorizontal ? zone.isBottom ? zone.height - point.y : point.y
            : zone.isRight ? zone.width - point.x : point.x;
        check(Math.abs(distance - edge) < 0.01, "Menu content moved away from its anchor during resize");
        const center = content.mapToItem(zone, content.width / 2, content.height / 2);
        const expected = Math.max(zone.edgeInset + zone.fullAlong / 2,
            Math.min(zone.total - zone.edgeInset - zone.fullAlong / 2, zone.anchorCenter));
        const offset = (zone.isHorizontal ? center.x : center.y) - expected;
        if (centered) check(Math.abs(offset) < 1, "Menu moved farther than needed to fit: " + offset);
        if (centered && !zone.isHorizontal)
        {
            check(Math.abs(zone.panel.width - content.width) < 0.01, "Vertical menu background is wider than its content");
            check(Math.abs(zone.panel.height - content.height) < 0.01, "Vertical menu background is taller than its content");
        }
        samples++;
    }
    function verifyAttachment()
    {
        const surface = zone.attachedMenu ? zone.attachedMenuRect : zone.panel.area;
        if (surface.width <= 0 || surface.height <= 0) return;
        const expected = zone.attachedMenu ? zone.islandDepth : zone.baseOuter + Theme.panelGap;
        check(Math.abs(nearEdge(surface) - expected) < 0.01, "Menu surface does not match its attachment or gap");
        const span = zone.isHorizontal ? surface.width : surface.height;
        const along = zone.isHorizontal ? surface.x : surface.y;
        if (zone.attachedMenu) check(along + span > zone.islandA0 && along < zone.islandA1, "Menu lost contact with its parent section");
        else check(along >= zone.edgeInset - 0.01 && along + span <= zone.total - zone.edgeInset + 0.01, "Floating menu crossed the frame gap");
        check(Math.abs((zone.isHorizontal ? surface.height : surface.width) + nearEdge(surface) - zone.menuNear - zone.menuDepth) < 0.01,
            "Menu content and surface reveal at different depths");
    }
    function advance()
    {
        phase++;
        since = Date.now();
    }
    Window
    {
        width: 1000; height: 700; visible: true
        BarZone
        {
            id: zone
            anchors.fill: parent
            side: Config.barSide
            align: "end"
            cornerInset: 20
            widgets: ["fixture"]
            islandDepth: 8
        }
        Item
        {
            id: trigger
            width: 24; height: 24
            x: zone.isHorizontal ? zone.islandA0 + 20 - width / 2 : 0
            y: zone.isHorizontal ? 0 : zone.islandA0 + 20 - height / 2
        }
    }
    Timer
    {
        interval: 16; repeat: true; running: true
        onTriggered:
        {
            try
            {
                const elapsed = Date.now() - tests.since;
                if (tests.phase > 0) tests.verifyAttachment();
                if (tests.phase === 0)
                {
                    tests.trial++;
                    if (tests.trial === 24)
                    {
                        tests.check(tests.samples > 100, "Not enough resize frames checked");
                        console.log("MENU_GEOMETRY_PASSED", tests.samples, "frames"); Qt.quit(); return;
                    }
                    Config.mode = Math.floor((tests.trial % 12) / 4);
                    zone.attachedMenu = tests.trial >= 12;
                    Config.barSide = tests.trial % 4;
                    tests.phase = -1;
                    tests.since = Date.now();
                }
                else if (tests.phase === -1 && elapsed > 80)
                {
                    MenuState.menuCurrent = String(Qt.resolvedUrl("ResizeMenu.qml"));
                    MenuState.menuOwner = zone;
                    MenuState.menuWidget = trigger;
                    MenuState.menuActive = true;
                    tests.phase = 1;
                    tests.since = Date.now();
                }
                else if (tests.phase === 1 && elapsed > 160 && zone.progress === 1)
                {
                    const view = zone.panel.children.find(item => item.front !== undefined);
                    tests.content = view.front.item;
                    tests.check(tests.content !== null, "Resize fixture did not load");
                    tests.check(tests.content.presented && tests.content.firstSection.reveal > 0, "Menu sections did not reveal");
                    tests.check(tests.content.firstSection.reveal >= tests.content.lastSection.reveal, "Menu sections reveal in the wrong order");
                    if (!Config.animationsEnabled) tests.check(tests.content.lastSection.reveal === 1, "Animations-off delayed a menu section");
                    tests.verify(true);
                    tests.content.implicitHeight = 320;
                    tests.advance();
                }
                else if (tests.phase >= 2 && tests.phase <= 4)
                {
                    tests.verify(elapsed > 160);
                    if (tests.phase === 3)
                    {
                        tests.check(Math.abs(zone.panel.height - tests.content.height) < 0.01,
                            "Menu surface lags behind its own animated content height");
                    }
                    if (elapsed < 200) return;
                    if (tests.phase === 2)
                    {
                        tests.content.contentAnimatesHeight = true;
                        tests.content.implicitHeight = 100;
                    }
                    else if (tests.phase === 3)
                    {
                        tests.content.contentAnimatesHeight = false;
                        tests.content.implicitWidth = 340;
                    }
                    else { MenuState.close(); tests.advance(); return; }
                    tests.advance();
                }
                else if (tests.phase === 5 && elapsed > 75)
                {
                    tests.check(!zone.panel.enabled, "Closing menu still accepts input");
                    if (Config.animationsEnabled)
                        tests.check(zone.progress > 0 && zone.progress < 1 && tests.content.presented, "Menu content disappeared before the surface retracted");
                    else tests.check(zone.progress === 0 && !tests.content.presented, "Animations-off delayed menu close");
                    const progress = zone.progress;
                    MenuState.menuActive = true;
                    if (Config.animationsEnabled) tests.check(zone.progress === progress, "Rapid reopen jumped to another size");
                    tests.advance();
                }
                else if (tests.phase === 6 && elapsed > 200)
                {
                    const view = zone.panel.children.find(item => item.front !== undefined);
                    tests.check(view.front.item === tests.content && tests.content.presented, "Rapid reopen replaced or left the menu hidden");
                    tests.check(tests.content.firstSection.reveal > 0 && tests.content.firstSection.reveal >= tests.content.lastSection.reveal, "Rapid reopen lost the section animation");
                    zone.align = "center";
                    tests.slot = zone.children.find(item => item.slots !== undefined).slots[0];
                    MenuState.menuWidget = tests.slot.widget;
                    tests.slot.widget.along = 500;
                    tests.advance();
                }
                else if (tests.phase === 7 || tests.phase === 8)
                {
                    tests.verifyIsland();
                    tests.verify(elapsed > 220);
                    if (elapsed < 250) return;
                    if (tests.phase === 7) tests.slot.widget.along = 140;
                    else tests.content.implicitHeight = 1100;
                    tests.advance();
                }
                else if (tests.phase === 9 && elapsed > 220)
                {
                    const view = zone.panel.children.find(item => item.front !== undefined);
                    tests.check(view.front.interactive && view.front.contentHeight > view.front.height, "Oversized menu did not get a scrolling viewport");
                    MenuState.close();
                    tests.advance();
                }
                else if (tests.phase === 10 && elapsed > 360)
                {
                    tests.check(zone.progress === 0 && zone.attachedMenuRect.width === 0 && !zone.panel.visible, "Closing animation left a menu surface behind");
                    tests.slot.widget.along = 300;
                    zone.align = "end";
                    tests.phase = 0;
                }
            }
            catch (error) { console.error("MENU_GEOMETRY_FAILED", error); Qt.quit() }
        }
    }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
               XDG_RUNTIME_DIR=str(base / "runtime"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"))
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=65)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "MENU_GEOMETRY_PASSED" in output, "Menu geometry checks failed"
    assert not re.search(r"MENU_GEOMETRY_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign", output), "Menu geometry QML error"

print("Attached and floating menus kept their geometry on all four edges through opening, resizing, scrolling, and rapid reopening.")
