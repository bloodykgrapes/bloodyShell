pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

import "../src/Clients.js" as Clients
import "../common"
import "../core"

Singleton
{
    id: serviceNetwork

    property string requestedNetwork: ""
    property string authNetwork: ""
    property var authDetails: ({ profile: false, username: "", method: "peap", inner: "mschapv2", domain: "", certificate: "" })
    readonly property bool authBusy: authenticator.running || authenticator.pending
    signal credentialsRequired(string name, bool enterprise)
    signal connectionFinished(string name, bool success, string message)

    function isEnterprise(security)
    {
        return security === WifiSecurityType.WpaEap || security === WifiSecurityType.Wpa2Eap;
    }

    function inspectEnterprise(name)
    {
        if (authBusy) return;
        authNetwork = name;
        authDetails = { profile: false, username: "", method: "peap", inner: "mschapv2", domain: "", certificate: "" };
        authenticator.run({ action: "inspect", ssid: name, interface: wifi ? wifi.name : "" });
    }

    function authError(code)
    {
        const messages = {
            toolsMissing: "service.network.toolsMissing",
            credentialsRequired: "service.network.credentialsRequired",
            invalidDomain: "service.network.invalidDomain",
            invalidCertificate: "service.network.invalidCertificate",
            unsupportedMethod: "service.network.unsupportedMethod",
            unavailable: "menu.network.outOfRange",
            connectionTimeout: "service.network.connectionTimeout",
            saveFailed: "service.network.saveFailed"
        };
        return Tr.tr(messages[code] || "service.network.connectionFailed");
    }

    Instantiator
    {
        model: serviceNetwork.wifi ? serviceNetwork.wifi.networks.values : []
        delegate: Connections
        {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason)
            {
                if (modelData.name !== serviceNetwork.requestedNetwork) return;
                if (serviceNetwork.authBusy) return;
                serviceNetwork.requestedNetwork = "";
                if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout)
                {
                    if (serviceNetwork.isEnterprise(modelData.security) || serviceNetwork.requiresPsk(modelData.security))
                        serviceNetwork.credentialsRequired(modelData.name, serviceNetwork.isEnterprise(modelData.security));
                    else serviceNetwork.connectionFinished(modelData.name, false, serviceNetwork.authError("unsupportedMethod"));
                }
                else serviceNetwork.connectionFinished(modelData.name, false, serviceNetwork.authError("connectionFailed"));
            }
            function onConnectedChanged()
            {
                if (modelData.connected && modelData.name === serviceNetwork.requestedNetwork && !serviceNetwork.authBusy)
                    serviceNetwork.requestedNetwork = "";
            }
        }
    }

    Process
    {
        id: authenticator
        property var request: null
        property bool pending: false
        property bool launched: false
        property string operation: ""
        property string network: ""
        stdinEnabled: true

        function run(data)
        {
            request = data;
            operation = data.action;
            network = data.ssid;
            pending = true;
            launched = false;
            exec(["python3", Paths.runtimeScriptsDir + "/network-auth"]);
        }
        function finish(output)
        {
            if (!pending) return;
            pending = false;
            request = null;
            let result;
            try { result = JSON.parse(output) } catch (error) { result = { ok: false, error: "connectionFailed" }; }
            if (operation === "inspect" && result.ok !== false) serviceNetwork.authDetails = result;
            else
            {
                serviceNetwork.requestedNetwork = "";
                serviceNetwork.connectionFinished(network, result.ok === true, result.ok ? "" : serviceNetwork.authError(result.error));
            }
        }
        onStarted:
        {
            launched = true;
            write(JSON.stringify(request) + "\n");
            request = null;
        }
        stdout: StdioCollector { onStreamFinished: authenticator.finish(text) }
        onExited: Qt.callLater(() => { if (authenticator.pending) authenticator.finish(""); })
        onRunningChanged: if (!running && pending && !launched) Qt.callLater(() => { if (!authenticator.running && !authenticator.launched) authenticator.finish(""); })
    }

    function findDevice(type)
    {
        const list = Networking.devices.values;
        let first = null;
        for (let i = 0; i < list.length; i++)
        {
            const d = list[i];
            if (d.type !== type) continue;
            if (d.connected) return d;
            if (first === null) first = d;
        }
        return first;
    }

    function findActive()
    {
        if (wifi === null) return null;
        const list = wifi.networks.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].connected) return list[i];
        return null;
    }

    function getList()
    {
        if (wifi === null) return [];
        const out = [];
        const list = wifi.networks.values;
        for (let i = 0; i < list.length; i++)
        {
            const n = list[i];
            if (!n.name) continue;
            out.push({
                name: n.name,
                strength: n.signalStrength,
                connected: n.connected,
                known: n.known,
                security: n.security,
                stateChanging: n.stateChanging
            });
        }
        out.sort((a, b) => (b.connected - a.connected) || (b.strength - a.strength) || a.name.localeCompare(b.name));
        return out;
    }

    function networkByName(name)
    {
        if (wifi === null || !name) return null;
        const list = wifi.networks.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].name === name) return list[i];
        return null;
    }

    readonly property bool refreshing: scanner.busy
    property string refreshError: ""

    function refreshNetworks()
    {
        if (!wifi || !enabledWiFi || !enabledWiFiHardware || refreshing) return false;
        refreshError = "";
        return scanner.run(["nmcli", "--wait", "15", "--terse", "--fields", "SSID", "device", "wifi", "list", "ifname", wifi.name, "--rescan", "yes"]);
    }

    CommandProcess
    {
        id: scanner
        stdout: StdioCollector {}
        onCompleted: code => { if (code !== 0) serviceNetwork.refreshError = Tr.tr("service.network.scanFailed"); }
    }

    property var scanClients: []
    readonly property int scanUsers: scanClients.length
    onScanUsersChanged: applyScanning()
    onWifiChanged: applyScanning()
    function applyScanning()
    {
        if (wifi !== null && wifi.scannerEnabled !== undefined) wifi.scannerEnabled = scanUsers > 0;
    }
    function setScanning(client, active)
    {
        scanClients = Clients.update(scanClients, client, active);
    }

    function strengthPercent(value)
    {
        const v = Number(value) || 0;
        return Math.round(v <= 1 ? v * 100 : v);
    }

    function setWifiEnabled(value)
    {
        if (!hasWiFi || !Networking.wifiHardwareEnabled) return;
        Networking.wifiEnabled = value === true;
    }

    function connectNetwork(name, password, username, options)
    {
        const network = networkByName(name);
        if (!network || !enabledWiFi) return "unavailable";
        if (authBusy || network.stateChanging) return "busy";
        if (network.connected)
        {
            requestedNetwork = "";
            network.disconnect();
            return "disconnecting";
        }

        if (isEnterprise(network.security) && password !== undefined)
        {
            if (!username || !password) return "credentials";
            const data = Object.assign({}, options || {}, { action: "connect", ssid: name, interface: wifi.name, username: String(username), password: String(password) });
            requestedNetwork = name;
            authenticator.run(data);
            return "connecting";
        }
        if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe)
        {
            requestedNetwork = name;
            network.connect();
            return "connecting";
        }

        if (isEnterprise(network.security)) return "credentials";

        if (!requiresPsk(network.security)) return "settings";
        if (password === undefined || password === null) return "password";
        const secret = String(password);
        if (secret.length === 0) return "password";
        requestedNetwork = name;
        network.connectWithPsk(secret);
        return "connecting";
    }

    function requiresPsk(security)
    {
        return security === WifiSecurityType.WpaPsk || security === WifiSecurityType.Wpa2Psk || security === WifiSecurityType.Sae;
    }

    readonly property var wifi: findDevice(DeviceType.Wifi)
    readonly property var wired: findDevice(DeviceType.Wired)

    readonly property bool hasWiFi: wifi !== null
    readonly property bool hasWired: wired !== null

    readonly property bool enabledWiFi: Networking.wifiEnabled
    readonly property bool enabledWiFiHardware: Networking.wifiHardwareEnabled
    readonly property bool connectedWiFi: hasWiFi && wifi.connected
    readonly property bool connectedEthernet: hasWired && wired.connected

    readonly property var    activeWifi: findActive()
    readonly property string ssid: activeWifi !== null ? activeWifi.name : ""
    readonly property real   signal: activeWifi !== null ? activeWifi.signalStrength : 0

    readonly property var wifiList: getList()

    function disconnectNetwork(name) { const n = networkByName(name); if (n && n.connected) n.disconnect() }

    function forgetNetwork(name) { const n = networkByName(name); if (n && n.known) n.forget() }

    property string wifiAddress: ""
    function refreshAddress()
    {
        if (!connectedWiFi || !wifi || !wifi.name) { wifiAddress = ""; return; }
        addressReader.command = ["ip", "-4", "-o", "addr", "show", "dev", wifi.name];
        addressReader.running = true;
    }
    onConnectedWiFiChanged: refreshAddress()
    onSsidChanged: refreshAddress()

    Process
    {
        id: addressReader
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const m = /inet\s+([0-9.]+)/.exec(text);
                serviceNetwork.wifiAddress = m ? m[1] : "";
            }
        }
    }
}
