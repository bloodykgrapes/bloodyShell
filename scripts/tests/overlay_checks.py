#!/usr/bin/env python3

from pathlib import Path
import re
import runpy
import subprocess
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
    QtObject
    {
        id: probeHost
        function activeFor(name) { return true; }
        function revealFor(name) { return 0.5; }
        function dismiss(name) {}
    }
    Component { id: viewProbe; OverlayView { host: probeHost; name: "probe" } }
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
                        probe.destroy();
                        Config.set("themeAnimations", 2);
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
                        tests.check(!overlay.preparedComponents.some(component => component.status === Component.Error), "An overlay failed to prepare");
                        if (overlay.preparedComponents.length < overlay.preparationOrder.length || overlay.preparedComponents.some(component => component.status === Component.Loading)) return;
                        tests.check(overlay.testPage.item === null && !OverlayState.active, "Preparing components created a live overlay");
                        tests.check(ServiceApplications.autostartClients.length === 0 && ServiceMedia.positionUsers === 0 && ServiceMedia.visualizerUsers === 0, "Background preparation subscribed hidden views");
                        step = 5; break;
                    case 5:
                        Config.set("themeAnimations", mode);
                        tests.pending = names[index]; tests.requested = Date.now();
                        OverlayState.show(names[index]);
                        step = 6; break;
                    case 6:
                        if (!overlay.testPage.item || overlay.testPage.item.name !== names[index]) return;
                        tests.check(overlay.testPage.item.ready && overlay.testPage.item.active, "Prepared overlay is not ready for input");
                        OverlayState.close(); step = 7; break;
                    case 7:
                        if (overlay.testPage.item || OverlayState.mounted !== "") return;
                        index++;
                        if (index >= names.length) { index = 0; mode++; }
                        if (mode < 3) { step = 5; break; }
                        tests.check(ServiceApplications.autostartClients.length === 0 && ServiceMedia.positionUsers === 0 && ServiceMedia.visualizerUsers === 0, "Closing overlays retained resource subscriptions");
                        console.log("OVERLAY_TIMINGS", JSON.stringify(tests.timings));
                        console.log("OVERLAYS_PASSED single entrance, first settings page, background preparation, modal/lock guards, opening and cleanup in every animation mode");
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


if __name__ == "__main__":
    checks()
