pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth

import "../../components/bar"
import "../../core"
import "../../services"
import "../../src/ModelSync.js" as ModelSync

Menu
{
    id: menuBluetooth

    implicitWidth: 320

    property bool startedScan: false
    Component.onDestruction: if (startedScan) ServiceBluetooth.setDiscovering(false)

    function status(d)
    {
        if (d.pairing) return Tr.tr("menu.bluetooth.pairing");
        if (d.state === BluetoothDeviceState.Connecting) return Tr.tr("common.connecting");
        if (d.state === BluetoothDeviceState.Disconnecting) return Tr.tr("common.disconnecting");
        if (d.connected) return d.batteryAvailable ? Math.round(d.battery * 100) + "%" : Tr.tr("common.connected");
        return d.paired ? Tr.tr("menu.bluetooth.paired") : "";
    }
    function item(d)
    {
        return {
            address: d.address,
            name: d.name || d.address,
            kind: String(d.icon || ""),
            status: status(d),
            connected: d.connected === true,
            working: d.pairing === true || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting,
            battery: d.connected && d.batteryAvailable ? d.battery : -1
        };
    }

    ListModel { id: connectedModel }
    ListModel { id: pairedModel }
    ListModel { id: nearbyModel }

    function sync()
    {
        const on = ServiceBluetooth.enabled;
        const list = on ? ServiceBluetooth.deviceList : [];
        ModelSync.sync(connectedModel, list.filter(d => d.connected).map(item), "address");
        ModelSync.sync(pairedModel, list.filter(d => !d.connected).map(item), "address");
        ModelSync.sync(nearbyModel, on && ServiceBluetooth.discovering ? ServiceBluetooth.nearby.slice(0, 6).map(item) : [], "address");
    }
    Component.onCompleted: sync()

    Timer { interval: 700; repeat: true; running: true; onTriggered: menuBluetooth.sync() }
    Connections
    {
        target: ServiceBluetooth
        function onDeviceListChanged()  { menuBluetooth.sync() }
        function onNearbyChanged()      { menuBluetooth.sync() }
        function onEnabledChanged()     { menuBluetooth.sync() }
        function onDiscoveringChanged() { menuBluetooth.sync() }
    }

    MenuToggle
    {
        icon: ServiceBluetooth.enabled ? Icon.bluetoothON : Icon.bluetoothOFF
        text: Tr.tr("common.bluetooth")

        enabled: ServiceBluetooth.available
        checked: ServiceBluetooth.enabled

        onToggle: value => ServiceBluetooth.setEnabled(value)
    }

    MenuLabel { hint: true; visible: !ServiceBluetooth.available; text: Tr.tr("menu.bluetooth.noBluetoothAdapter") }

    MenuSeparator { visible: ServiceBluetooth.enabled }

    MenuLabel { visible: connectedModel.count > 0; text: Tr.tr("common.connected") }

    MenuList
    {
        model: connectedModel
        opening: menuBluetooth.opening

        delegate: DeviceRow
        {
            id: connectedRow
            MenuRowAction { icon: Icon.linkOff; label: Tr.tr("common.disconnect"); onClicked: ServiceBluetooth.disconnect(connectedRow.address) }
            MenuRowAction { icon: Icon.trash; label: Tr.tr("common.forget"); danger: true; onClicked: ServiceBluetooth.forget(connectedRow.address) }
        }
    }

    MenuLabel { visible: pairedModel.count > 0; text: Tr.tr("menu.bluetooth.devices") }
    MenuLabel { hint: true; visible: ServiceBluetooth.enabled && connectedModel.count === 0 && pairedModel.count === 0; text: Tr.tr("menu.bluetooth.noPairedDevices") }

    MenuList
    {
        model: pairedModel
        opening: menuBluetooth.opening

        delegate: DeviceRow
        {
            id: pairedRow
            MenuRowAction { icon: Icon.trash; label: Tr.tr("common.forget"); danger: true; onClicked: ServiceBluetooth.forget(pairedRow.address) }
        }
    }

    MenuSeparator { visible: ServiceBluetooth.enabled }

    MenuRow
    {
        visible: ServiceBluetooth.enabled

        icon: ServiceBluetooth.discovering ? Icon.bluetoothSearching : Icon.reload
        text: ServiceBluetooth.discovering ? Tr.tr("menu.bluetooth.searching") : Tr.tr("menu.bluetooth.searchForDevices")
        busy: ServiceBluetooth.discovering

        onClicked:
        {
            menuBluetooth.startedScan = !ServiceBluetooth.discovering;
            ServiceBluetooth.setDiscovering(!ServiceBluetooth.discovering);
        }
    }

    MenuList
    {
        model: nearbyModel

        delegate: MenuRow
        {
            required property string address
            required property string name
            required property string kind
            required property bool   working

            width: ListView.view ? ListView.view.rowWidth : 300
            icon: Icon.bluetoothDevice(kind)
            text: name
            subtitle: working ? Tr.tr("menu.bluetooth.pairing") : Tr.tr("menu.bluetooth.clickToPair")
            busy: working

            onClicked: ServiceBluetooth.activate(ServiceBluetooth.deviceBy(address))
        }
    }

    component DeviceRow: MenuRow
    {
        required property string address
        required property string name
        required property string kind
        required property string status
        required property bool   connected
        required property bool   working
        required property real   battery

        width: ListView.view ? ListView.view.rowWidth : 300
        icon: Icon.bluetoothDevice(kind)
        text: name
        subtitle: status
        level: battery
        selected: connected
        busy: working

        onClicked: ServiceBluetooth.activate(ServiceBluetooth.deviceBy(address))
    }
}
