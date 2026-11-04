pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton
{
    function getList()
    {
        const out = devices.filter(d => d.paired || d.connected);
        out.sort((a, b) => (b.connected - a.connected) || String(a.name).localeCompare(String(b.name)));
        return out;
    }

    readonly property var adapter: Bluetooth.defaultAdapter

    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter !== null ? adapter.enabled : false

    readonly property var  devices: adapter !== null ? adapter.devices.values : []
    readonly property var  connectedDevices: devices.filter(d => d.connected)
    readonly property bool connected: connectedDevices.length > 0

    readonly property var deviceList: getList()

    readonly property bool discovering: adapter !== null ? adapter.discovering : false
    readonly property var  nearby: devices.filter(d => !d.paired && !d.connected && d.name && d.name !== d.address.replace(/:/g, "-"))

    function setDiscovering(value)
    {
        if (adapter && adapter.enabled) adapter.discovering = value === true;
    }

    function activate(device)
    {
        if (!device) return;
        if (!device.paired) { device.pair(); return; }
        if (device.connected) device.disconnect();
        else device.connect();
    }

    function deviceBy(address) { return devices.find(d => d.address === address) || null }
    function disconnect(address) { const d = deviceBy(address); if (d && d.connected) d.disconnect() }

    function forget(address) { const d = deviceBy(address); if (d) d.forget() }

    function setEnabled(value)
    {
        if (!adapter) return;
        adapter.enabled = value === true;
    }
}
