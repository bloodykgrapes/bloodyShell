pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton
{
    id: serviceNetwork

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

    property int scanUsers: 0
    onWifiChanged: applyScanning()
    function applyScanning()
    {
        if (wifi !== null && wifi.scannerEnabled !== undefined) wifi.scannerEnabled = scanUsers > 0;
    }
    function setScanning(value)
    {
        scanUsers = Math.max(0, scanUsers + (value === true ? 1 : -1));
        applyScanning();
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

    function connectNetwork(name, password)
    {
        const network = networkByName(name);
        if (!network || !enabledWiFi) return "unavailable";
        if (network.connected)
        {
            network.disconnect();
            return "disconnecting";
        }

        if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe)
        {
            network.connect();
            return "connecting";
        }

        const needsPsk = network.security === WifiSecurityType.WpaPsk
            || network.security === WifiSecurityType.Wpa2Psk
            || network.security === WifiSecurityType.Sae;
        if (!needsPsk) return "settings";
        if (password === undefined || password === null) return "password";
        const secret = String(password);
        if (secret.length === 0) return "password";
        network.connectWithPsk(secret);
        return "connecting";
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
