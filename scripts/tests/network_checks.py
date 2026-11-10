#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def backend_checks():
    api = runpy.run_path(str(ROOT / "scripts/runtime/network-auth"))
    Gio, GLib, NM = api["libraries"]()
    build = api["connection_for"]
    request = dict(ssid="Enterprise '$(example)'", interface="wlan-test", username="user@example.org", password="literal password '$(not-a-command)'", domain="auth.example.org", method="peap", inner="mschapv2")
    connection = build(request, None, GLib, NM)
    assert connection.verify()
    eap = connection.get_setting_802_1x()
    assert eap.get_identity() == request["username"] and eap.get_password() == request["password"]
    assert eap.get_system_ca_certs() and eap.get_domain_suffix_match() == request["domain"]
    assert bytes(connection.get_setting_wireless().get_ssid().get_data()) == request["ssid"].encode()
    assert "password" not in api["describe"](connection)
    connection.get_setting_ip4_config().set_property("dns-priority", 42)
    modified = build(dict(request, username="updated-user", password="updated-password", domain="different.invalid", method="ttls"), connection, GLib, NM)
    assert modified.get_setting_802_1x().get_domain_suffix_match() == request["domain"]
    assert modified.get_setting_802_1x().get_eap_method(0) == "peap"
    assert modified.get_setting_ip4_config().get_dns_priority() == 42
    assert eap.get_password() == request["password"], "Editing a clone must not alter an existing profile before submission"
    assert build(dict(request, method="ttls", inner="pap"), None, GLib, NM).verify()
    without_domain = build(dict(request, domain=""), None, GLib, NM)
    assert without_domain.verify() and without_domain.get_setting_802_1x().get_system_ca_certs()
    assert not without_domain.get_setting_802_1x().get_domain_suffix_match()
    with tempfile.TemporaryDirectory(prefix="bloodyshell-ca-") as temporary:
        certificate = Path(temporary) / "provider CA.pem"
        certificate.write_text("test certificate")
        custom = build(dict(request, certificate=str(certificate)), None, GLib, NM)
        assert custom.get_setting_802_1x().get_ca_cert_path() == str(certificate)
        assert not custom.get_setting_802_1x().get_system_ca_certs()
    for changes, expected in ((dict(username=""), "credentialsRequired"), (dict(password=""), "credentialsRequired"), (dict(domain="bad/path"), "invalidDomain"), (dict(method="tls"), "unsupportedMethod"), (dict(certificate="/missing/certificate.pem"), "invalidCertificate")):
        try:
            build(dict(request, **changes), None, GLib, NM)
        except api["AuthError"] as error:
            assert str(error) == expected
        else:
            raise AssertionError(changes)

    class AP:
        def get_ssid(self): return GLib.Bytes.new(request["ssid"].encode())
        def get_strength(self): return 90
        def get_path(self): return "/test/access-point"

    class Device:
        def get_access_points(self): return [AP()]

    class Remote:
        def commit_changes_async(self, save, cancel, callback):
            assert save
            GLib.idle_add(lambda: callback(self, None))
        def commit_changes_finish(self, result): return True

    class Active:
        def connect(self, signal, callback): pass
        def get_state(self): return NM.ActiveConnectionState.ACTIVATED
        def get_connection(self): return Remote()

    class Client:
        def get_device_by_iface(self, name): return Device() if name == "wlan-test" else None
        def get_connections(self): return []
        def add_and_activate_connection2(self, profile, device, ap, options, cancel, callback):
            assert options.unpack()["persist"] == "volatile", "Do not save failed new profiles"
            GLib.idle_add(lambda: callback(self, None))
        def add_and_activate_connection2_finish(self, result): return Active(), None

    with patch.object(NM.Client, "new", return_value=Client()):
        assert api["perform"](dict(request, action="inspect"))["profile"] is False
        assert api["perform"](dict(request, action="connect"))["ok"]
    print("Enterprise settings, literal credentials, certificate checks, saved-profile preservation and activation passed without a network connection.")


def ui_checks():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-network-") as temporary:
        base = Path(temporary)
        shutil.copytree(ROOT / "modules", base / "modules")
        for name in ("assets", "translations"):
            (base / name).symlink_to(ROOT / name)
        for name in ("runtime", "cache", "config/bloodyShell", "scripts/runtime", "bin"):
            (base / name).mkdir(parents=True, mode=0o700)
        (base / "config/bloodyShell/settings.json").write_text(json.dumps(dict(helperSeen=True, themeAnimations=0, shellLanguage="en")))
        for name in ("niri", "awww"):
            path = base / "bin" / name
            path.write_text("#!/bin/sh\nexit 1\n")
            path.chmod(0o700)
        nmcli = base / "bin/nmcli"
        nmcli.write_text(f'''#!/usr/bin/env python3
import json, sys, time
from pathlib import Path
calls = Path({str(base / "scan-calls.jsonl")!r})
with calls.open('a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\\n')
time.sleep(0.3)
sys.exit(1 if len(calls.read_text().splitlines()) > 1 else 0)
''')
        nmcli.chmod(0o700)
        helper = base / "scripts/runtime/network-auth"
        helper.write_text('''import json, sys
from pathlib import Path
request=json.loads(sys.stdin.readline())
assert len(sys.argv)==1, "Credentials must never be passed in argv"
if request["action"]=="inspect":
    print(json.dumps(dict(profile=request["ssid"]=="Saved",username="saved-user" if request["ssid"]=="Saved" else "",method="peap",inner="mschapv2",domain="auth.example.org" if request["ssid"]=="Saved" else "",certificate="")))
else:
    assert request["username"]=="user@example.org" and request["domain"]==""
    assert request["password"] in ("wrong-password", "correct-password")
    print(json.dumps(dict(ok=request["password"]=="correct-password",error="connectionFailed")))
''')
        source = (base / "modules/services/ServiceNetwork.qml").read_text()
        source = source.replace("Networking.devices", "TestNetworking.devices").replace("Networking.wifi", "TestNetworking.wifi")
        (base / "modules/services/ServiceNetwork.qml").write_text(source)
        bluetooth = base / "modules/services/ServiceBluetooth.qml"
        bluetooth.write_text(bluetooth.read_text().replace('import Quickshell.Bluetooth', 'import "../core"\nimport Quickshell.Bluetooth').replace("Bluetooth.defaultAdapter", "TestBluetooth.adapter"))
        (base / "modules/core/qmldir").open("a").write("\nsingleton TestNetworking 1.0 TestNetworking.qml\nsingleton TestBluetooth 1.0 TestBluetooth.qml\n")
        (base / "modules/core/TestBluetooth.qml").write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property var adapter: null }\n')
        (base / "modules/core/TestNetworking.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton { property var devices: ({values:[]}); property bool wifiEnabled: true; property bool wifiHardwareEnabled: true }
''')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import "modules/core"
import "modules/services"
import "modules/ui/bar/menus"
import "modules/ui/overlay/settings/pages"
ShellRoot
{
    id: tests
    component Network: QtObject
    {
        property string name: ""
        property bool connected: false
        property bool known: false
        property bool stateChanging: false
        property real signalStrength: 0.8
        property int security: WifiSecurityType.Wpa2Eap
        property int connects: 0
        property string psk: ""
        signal connectionFailed(int reason)
        function connect() { connects++; if (known) Qt.callLater(() => connectionFailed(ConnectionFailReason.NoSecrets)); }
        function connectWithPsk(value) { psk = value; }
        function disconnect() { connected = false; }
        function forget() { known = false; }
    }
    Network { id: personal; name: "Personal"; security: WifiSecurityType.Wpa2Psk }
    Network { id: enterprise; name: "Enterprise" }
    Network { id: saved; name: "Saved"; known: true }
    QtObject
    {
        id: device
        property int type: DeviceType.Wifi
        property bool connected: false
        property string name: "wlan-test"
        property bool scannerEnabled: false
        property var networks: ({ values: [personal, enterprise, saved] })
    }
    QtObject
    {
        id: ethernet
        property int type: DeviceType.Wired
        property bool connected: true
        property bool hasLink: true
        property string name: "ethernet-test"
        property var network: null
    }
    component BluetoothDevice: QtObject
    {
        property string address: ""
        property string name: ""
        property string icon: "audio-headset"
        property bool connected: false
        property bool paired: false
        property bool pairing: false
        property int state: BluetoothDeviceState.Disconnected
        property bool batteryAvailable: true
        property real battery: 0.65
        function pair() { pairing = true; }
        function connect() { connected = true; }
        function disconnect() { connected = false; }
        function forget() { paired = false; connected = false; }
    }
    BluetoothDevice { id: headphones; name: "Headphones"; address: "AA:01"; connected: true; paired: true }
    BluetoothDevice { id: keyboard; name: "Keyboard"; address: "AA:02"; paired: true }
    BluetoothDevice { id: nearby; name: "Speaker"; address: "AA:03" }
    QtObject
    {
        id: adapter
        property bool enabled: true
        property bool discovering: false
        property var devices: ({values:[headphones, keyboard, nearby]})
    }
    Component.onCompleted:
    {
        TestNetworking.devices = {values:[device, ethernet]};
        TestBluetooth.adapter = adapter;
    }
    Window
    {
        id: window
        visible: true
        width: 800; height: 900
        PageNetworks { id: page; anchors.fill: parent }
        MenuNetwork { id: menu; visible: false; width: 320; height: implicitHeight }
        MenuBluetooth { id: bluetoothMenu; visible: false; width: 320; height: implicitHeight }
        TestCase { id: input; when: false; optional: true }
        function matching(item, predicate) {
            if (predicate(item)) return item;
            for (const child of item.children || []) { const found = matching(child, predicate); if (found) return found; }
            return null;
        }
        function find(item) {
            if (item.canSubmit !== undefined && item.clearSecret !== undefined) return item;
            for (const child of item.children || []) { const found = find(child); if (found) return found; }
            return null;
        }
        function check(ok, text) { if (!ok) throw new Error(text); }
        function field(item, placeholder) {
            if (item.placeholder === placeholder) return item;
            for (const child of item.children || []) { const found = field(child, placeholder); if (found) return found; }
            return null;
        }
        Timer
        {
            interval: 220; repeat: true; running: Config.initialized
            property int step: -4
            property bool second: false
            onTriggered:
            {
                try
                {
                    const target = second ? menu : page;
                    if (step === -4)
                    {
                        window.check(ServiceNetwork.scanUsers === 1, "Hidden menu registered a scan consumer");
                        ServiceNetwork.setScanning(page, true);
                        ServiceNetwork.setScanning(page, true);
                        window.check(ServiceNetwork.scanUsers === 1, "Duplicate registration changed scan ownership");
                        page.visible = false;
                        window.check(ServiceNetwork.scanUsers === 0 && !device.scannerEnabled, "Hidden settings retained network scanning");
                        page.visible = true;
                        window.check(ServiceNetwork.refreshNetworks(), "Manual refresh did not start");
                        window.check(ServiceNetwork.refreshing && !ServiceNetwork.refreshNetworks(), "Duplicate refresh was allowed");
                        step++; return;
                    }
                    if (step === -3)
                    {
                        if (ServiceNetwork.refreshing) return;
                        window.check(ServiceNetwork.refreshError === "", "Successful refresh reported an error");
                        const radio = window.matching(menu, item => item.objectName === "networkRadio");
                        menu.visible = true;
                        radio.forceActiveFocus(); input.keyClick(Qt.Key_Space);
                        window.check(!ServiceNetwork.enabledWiFi && !radio.checked, "Wi-Fi tile did not disable the radio from keyboard");
                        window.check(!ServiceNetwork.refreshNetworks(), "Refresh started while Wi-Fi was off");
                        radio.toggle();
                        window.check(ServiceNetwork.enabledWiFi && radio.checked, "Wi-Fi tile did not enable the radio");
                        TestNetworking.wifiHardwareEnabled = false;
                        window.check(!radio.available, "Blocked radio retained available controls");
                        window.check(!window.matching(menu, item => item.visible && item.text === "Personal" && item.hasActions !== undefined), "Blocked radio retained stale networks");
                        window.check(!ServiceNetwork.refreshNetworks(), "Refresh started while hardware was blocked");
                        TestNetworking.wifiHardwareEnabled = true;
                        menu.visible = false;
                        ServiceNetwork.refreshNetworks();
                        step++; return;
                    }
                    if (step === -2)
                    {
                        if (ServiceNetwork.refreshing) return;
                        window.check(ServiceNetwork.refreshError !== "" && menu.status !== "" && page.status !== "", "Failed refresh did not report an error");
                        const wired = window.matching(menu, item => item.text === Tr.tr("menu.network.ethernet") && item.prominent !== undefined);
                        window.check(wired && wired.prominent && !wired.interactive && wired.selected, "Ethernet does not use the shared status card");
                        ethernet.connected = false;
                        window.check(wired.subtitle.includes(Tr.tr("common.notConnected")), "An inactive Ethernet link was labelled unplugged");
                        ethernet.hasLink = false;
                        window.check(wired.subtitle.includes(Tr.tr("menu.network.cableUnplugged")), "Missing cable status is incorrect");
                        step++; return;
                    }
                    if (step === -1)
                    {
                        menu.visible = true;
                        const personalRow = window.matching(menu, item => item.text === "Personal" && item.hasActions !== undefined);
                        window.check(personalRow && !personalRow.hasActions, "Hidden forget action hides network status marks");
                        window.check(ServiceNetwork.scanUsers === 2, "Overlapping views did not share scanning");
                        menu.visible = false;
                        window.check(ServiceNetwork.scanUsers === 1, "Hiding one view stopped another consumer");
                        step++; return;
                    }
                    if (step >= 6)
                    {
                        const row = name => window.matching(bluetoothMenu, item => item.text === name && item.prominent !== undefined);
                        const search = window.matching(bluetoothMenu, item => item.actionText !== undefined && item.text === Tr.tr("menu.bluetooth.nearby"));
                        if (step === 6)
                        {
                            window.check(row("Headphones") && row("Headphones").prominent && row("Headphones").subtitle === "65%", "Connected Bluetooth card is missing");
                            window.check(row("Keyboard") && !row("Keyboard").prominent, "Paired Bluetooth row is missing");
                            window.check(row("Keyboard").subtitle === Tr.tr("menu.bluetooth.paired"), "Device status retained an untranslated label");
                            window.check(row("Speaker"), "Nearby device vanished while not scanning");
                            search.actionTriggered();
                            window.check(adapter.discovering && bluetoothMenu.startedScan, "Bluetooth search did not start");
                            headphones.battery = 0.42;
                            nearby.pairing = true;
                        }
                        if (step === 7)
                        {
                            window.check(row("Headphones").subtitle === "42%", "Battery change did not update without polling");
                            window.check(row("Speaker").busy, "Pairing change did not update without polling");
                            search.actionTriggered();
                            window.check(!adapter.discovering && !bluetoothMenu.startedScan && row("Speaker"), "Stopping search discarded results");
                            ServiceBluetooth.disconnect(headphones.address);
                        }
                        if (step === 8)
                        {
                            window.check(row("Headphones") && !row("Headphones").prominent, "Disconnected device did not move to the paired list");
                            search.actionTriggered();
                            bluetoothMenu.visible = false;
                            window.check(!adapter.discovering && !bluetoothMenu.startedScan, "Hidden Bluetooth menu retained owned discovery");
                            bluetoothMenu.visible = true;
                            adapter.enabled = false;
                        }
                        if (step === 9)
                        {
                            window.check(!row("Headphones") && !row("Speaker"), "Devices remained after Bluetooth was disabled");
                            const radio = window.matching(bluetoothMenu, item => item.objectName === "bluetoothRadio");
                            window.check(!radio.checked && radio.available, "Bluetooth tile state is incorrect");
                            radio.forceActiveFocus(); input.keyClick(Qt.Key_Space);
                            window.check(adapter.enabled && radio.checked, "Bluetooth tile did not enable the radio from keyboard");
                            console.log("NETWORK_UI_PASSED credentials, manual refresh, Ethernet states, Bluetooth discovery, battery and pairing updates");
                            TestNetworking.devices = {values:[]};
                            TestBluetooth.adapter = null;
                            stop(); Qt.callLater(() => Qt.quit()); return;
                        }
                        step++; return;
                    }
                    const form = window.find(target);
                    const fields = form.children.filter(item => item.placeholder !== undefined);
                    const login = fields[0], password = fields[1], domain = window.field(form, Tr.tr("settings.networks.serverDomain"));
                    if (ServiceNetwork.authBusy) return;
                    if (step === 0) target.activate("Personal");
                    if (step === 1)
                    {
                        window.check(target.passwordFor === "Personal" && !form.enterprise, "Personal Wi-Fi incorrectly asks for username");
                        password.text = "personal-secret"; form.submitted();
                        window.check(personal.psk === "personal-secret" && form.password === "", "Personal password was not sent or cleared");
                        target.activate("Enterprise");
                    }
                    if (step === 2)
                    {
                        window.check(form.enterprise && target.passwordFor === "Enterprise", "Enterprise Wi-Fi did not ask for credentials");
                        login.text = "user@example.org"; password.text = "wrong-password";
                        window.check(!domain.visible && domain.text === "", "Optional server domain leaked into the main form");
                        form.advanced = true;
                        window.check(domain.visible && form.canSubmit, "An empty optional domain blocks sign-in");
                        form.advanced = false;
                        window.check(form.canSubmit, "Valid enterprise form is disabled");
                        form.submitted();
                        window.check(form.password === "", "Clear password after sending");
                    }
                    if (step === 3)
                    {
                        window.check(target.status !== "" && target.passwordFor === "Enterprise", "Failed authentication hid the retry form");
                        window.check(login.text === "user@example.org", "Retry discarded username");
                        password.text = "correct-password"; form.submitted();
                    }
                    if (step === 4)
                    {
                        window.check(target.passwordFor === "" && form.password === "", "Successful authentication did not clear the form");
                        target.activate("Saved");
                    }
                    if (step === 5)
                    {
                        window.check(form.enterprise && form.details.profile && form.username === "saved-user", "Saved enterprise credentials were not loaded after NoSecrets");
                        window.check(!domain.visible, "Saved profiles should keep their certificate settings");
                        form.cancelled();
                        window.check(form.username === "" && form.password === "", "Cancel retained credentials");
                        if (!second) { page.visible = false; menu.visible = true; second = true; step = 0; return; }
                        menu.visible = false; bluetoothMenu.visible = true;
                    }
                    step++;
                }
                catch (error) { console.error("NETWORK_UI_FAILED", second, step, error); Qt.quit(); }
            }
        }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"), PATH=str(base / "bin") + os.pathsep + os.environ["PATH"], DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-bus", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-system-bus")
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "NETWORK_UI_PASSED" in output, output
        assert not re.search(r"NETWORK_UI_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output
        scans = [json.loads(line) for line in (base / "scan-calls.jsonl").read_text().splitlines()]
        assert scans == [["--wait", "15", "--terse", "--fields", "SSID", "device", "wifi", "list", "ifname", "wlan-test", "--rescan", "yes"]] * 2, scans


if __name__ == "__main__":
    backend_checks()
    ui_checks()
