#!/usr/bin/env python3

import json
from pathlib import Path
import re
import runpy
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-about-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        env["TEST_ABOUT_BASE"] = str(base)
        (base / "config/bloodyShell/settings.json").write_text(json.dumps(dict(helperSeen=True, themeAnimations=0, themeAccent=True, shellLanguage="en")))
        (base / "system").mkdir()
        files = {
            "/etc/os-release": ('release', 'ID=example\nNAME="Example Linux"\nPRETTY_NAME="Example Linux 1.0"\n'),
            "/proc/sys/kernel/hostname": ('host', 'test-machine\n'),
            "/proc/sys/kernel/osrelease": ('kernel', '6.12-test\n'),
            "/sys/class/dmi/id/sys_vendor": ('vendor', 'Example\n'),
            "/sys/class/dmi/id/product_name": ('product', 'Example Very Long Device Model for Responsive Layout Verification\n'),
            "/proc/cpuinfo": ('cpu', 'processor : 0\nmodel name : Example(R) Processor(TM) with a Very Long Model Name 123456789\nprocessor : 1\n'),
            "/proc/meminfo": ('memory', 'MemTotal:       16777216 kB\n'),
        }
        service = base / "modules/services/ServiceSystem.qml"
        source = service.read_text()
        for original, (name, content) in files.items():
            path = base / "system" / name
            path.write_text(content)
            source = source.replace(json.dumps(original), json.dumps(str(path)))
        service.write_text(source)
        (base / "modules/services/ServiceAppearance.qml").write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property color accent: "#b599ff"; function iconPath(name) { return ""; } }\n')
        (base / "modules/services/ServiceUpdate.qml").write_text('pragma Singleton\nimport Quickshell\nSingleton { property string repo: "bloodykgrapes/bloodyShell"; property string version: "0.0.2"; property bool versionReady: true; property bool installed: false; function showPage() {} }\n')
        (base / "calls").write_text("")
        tool = '''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
import time
base = Path(os.environ["TEST_ABOUT_BASE"])
name = Path(sys.argv[0]).name
with (base / "calls").open("a") as stream: stream.write(name + "\\n")
time.sleep(0.05)
if name == "niri":
    assert sys.argv[1:] == ["--version"]
    print("niri 25.11-test")
elif name == "lspci":
    assert sys.argv[1:] == ["-mm"]
    if (base / "missing").exists(): sys.exit(127)
    print('00:02.0 "VGA compatible controller" "Intel Corporation" "Chip [Iris Xe Graphics]"')
    print('01:00.0 "3D controller" "NVIDIA Corporation" "Chip [GeForce Test]"')
    print('02:00.0 "Display controller" "NVIDIA Corporation" "Chip [GeForce Test]"')
    print('00:1f.3 "Audio device" "Intel Corporation" "Audio"')
else:
    raise AssertionError(name)
'''
        for name in ("niri", "lspci"):
            path = base / "bin" / name
            path.write_text(tool)
            path.chmod(0o700)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"

ShellRoot
{
    id: tests
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name)
    {
        if (item.objectName === name) return item;
        for (const child of item.children || []) { const result = find(child, name); if (result) return result; }
        return null;
    }
    FileView { id: calls; path: Quickshell.env("TEST_ABOUT_BASE") + "/calls"; blockLoading: true }
    FileView { id: host; path: Quickshell.env("TEST_ABOUT_BASE") + "/system/host"; blockLoading: true }
    FileView { id: memory; path: Quickshell.env("TEST_ABOUT_BASE") + "/system/memory"; blockLoading: true }
    FileView { id: missing; path: Quickshell.env("TEST_ABOUT_BASE") + "/missing"; printErrors: false }
    function count() { calls.reload(); calls.waitForJob(); return calls.text().split("\\n").filter(Boolean).length; }
    Window
    {
        id: window
        visible: true; width: 860; height: 1000; color: Theme.settingsColorBackground
        Loader { id: page; anchors.fill: parent; active: false; sourceComponent: Component { PageAbout {} } }
    }
    Timer
    {
        interval: 150; repeat: true; running: Config.initialized
        property int step: 0
        property int waits: 0
        onTriggered:
        {
            try
            {
                tests.check(++waits < 60, "About checks did not finish");
                switch (step)
                {
                    case 0:
                        void ServiceSystem.distribution;
                        tests.check(!ServiceSystem.detailsRequested && tests.count() === 0, "System service probes hardware before it is requested");
                        const arm = ServiceSystem.cpuInfo("processor : 0\\nprocessor : 1\\nHardware : Example ARM board\\n");
                        tests.check(arm.name === "Example ARM board" && arm.threads === 2, "ARM processor fallback is incorrect");
                        page.active = true; step = 1; break;
                    case 1:
                        if (ServiceSystem.loading || ServiceSystem.memoryKiB === 0) return;
                        tests.check(ServiceSystem.hostname === "test-machine" && ServiceSystem.kernel === "6.12-test" && ServiceSystem.compositor === "25.11-test", "System information is incomplete");
                        tests.check(ServiceSystem.processor === "Example Processor with a Very Long Model Name 123456789" && ServiceSystem.threads === 2, "Processor parsing is incorrect");
                        tests.check(ServiceSystem.device === "Example Very Long Device Model for Responsive Layout Verification", "Device name repeats its vendor");
                        tests.check(ServiceSystem.memoryKiB === 16777216 && ServiceSystem.graphics.join(",") === "Intel Iris Xe Graphics,NVIDIA GeForce Test", "Memory or graphics parsing is incorrect");
                        tests.check(tests.count() === 2, "Initial hardware detection runs more than once");
                        tests.check(tests.find(page.item, "aboutShellCard") && tests.find(page.item, "aboutProcessor"), "Identity card or hardware information is missing");
                        step = 5;
                        page.item.grabToImage(result => { result.saveToFile("/tmp/bloodyshell-about-dark.png"); page.active = false; step = 2; });
                        break;
                    case 2:
                        Config.set("shellLanguage", "ru"); Config.set("themeStyle", 0);
                        window.width = 520; window.height = 760;
                        page.active = true; step = 3; break;
                    case 3:
                        tests.check(tests.count() === 2, "Reopening About repeats hardware detection");
                        const cpu = tests.find(page.item, "aboutProcessor"), gpu = tests.find(page.item, "aboutGraphics");
                        tests.check(cpu.stacked && gpu.stacked && cpu.height > 56 && gpu.height > 56, "Long hardware names are truncated on a narrow page");
                        tests.check(page.item.projectUrl === "https://github.com/bloodykgrapes/bloodyShell", "Project links use the wrong repository");
                        page.item.grabToImage(result => result.saveToFile("/tmp/bloodyshell-about-light-ru.png"));
                        host.waitForJob(); host.setText("renamed-machine\\n");
                        memory.waitForJob(); memory.setText("unavailable\\n");
                        host.waitForJob(); memory.waitForJob();
                        missing.setText("1"); missing.waitForJob();
                        tests.find(page.item, "aboutRefresh").clicked();
                        ServiceSystem.refresh(); step = 4; break;
                    case 4:
                        if (ServiceSystem.loading || ServiceSystem.hostname !== "renamed-machine") return;
                        tests.check(tests.count() === 4, "Refresh overlaps another hardware probe");
                        tests.check(ServiceSystem.memoryKiB === 0 && ServiceSystem.graphics.length === 0, "Unavailable hardware retained stale values");
                        tests.check(tests.find(page.item, "aboutGraphics").display === Tr.tr("settings.about.unavailable"), "Unavailable graphics does not show a translated fallback");
                        ServiceSystem.vendor = "To Be Filled By O.E.M."; ServiceSystem.product = "System Product Name";
                        tests.check(ServiceSystem.device === "" && !tests.find(page.item, "aboutDevice").visible, "Placeholder firmware values are shown as device names");
                        console.log("ABOUT_PASSED lazy cached hardware, parsing, refresh, missing devices, themes, translations and responsive layout");
                        Qt.quit(); break;
                }
            }
            catch (error) { console.error("ABOUT_FAILED", step, error); Qt.quit(); }
        }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "ABOUT_PASSED" in output, output
        assert not re.search(r"ABOUT_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


if __name__ == "__main__":
    checks()
