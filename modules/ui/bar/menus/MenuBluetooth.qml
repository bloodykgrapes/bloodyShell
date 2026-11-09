pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Quickshell.Bluetooth

import "../../../src/ModelSync.js" as ModelSync
import "../../../common"
import "../../../core"
import "../../../services"

Menu
{
    id: menuBluetooth

    implicitWidth: 320

    property bool startedScan: false
    onActiveChanged: if (!active) stopScanning()
    Component.onDestruction: stopScanning()

    function stopScanning()
    {
        if (!startedScan) return;
        startedScan = false;
        ServiceBluetooth.setDiscovering(false);
    }

    function deviceStatus(d)
    {
        if (d.pairing) return "menu.bluetooth.pairing";
        if (d.state === BluetoothDeviceState.Connecting) return "common.connecting";
        if (d.state === BluetoothDeviceState.Disconnecting) return "common.disconnecting";
        if (d.connected) return "common.connected";
        return d.paired ? "menu.bluetooth.paired" : "";
    }
    function item(d)
    {
        return {
            address: d.address,
            name: d.name || d.address,
            kind: String(d.icon || ""),
            statusKey: deviceStatus(d),
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
        ModelSync.sync(nearbyModel, on ? ServiceBluetooth.nearby.map(item) : [], "address");
    }
    function scheduleSync() { Qt.callLater(sync) }
    Component.onCompleted: sync()

    Instantiator
    {
        model: ServiceBluetooth.devices
        delegate: Connections
        {
            required property var modelData
            target: modelData
            function onNameChanged() { menuBluetooth.scheduleSync() }
            function onConnectedChanged() { menuBluetooth.scheduleSync() }
            function onPairedChanged() { menuBluetooth.scheduleSync() }
            function onStateChanged() { menuBluetooth.scheduleSync() }
            function onPairingChanged() { menuBluetooth.scheduleSync() }
            function onBatteryChanged() { menuBluetooth.scheduleSync() }
            function onBatteryAvailableChanged() { menuBluetooth.scheduleSync() }
            function onIconChanged() { menuBluetooth.scheduleSync() }
        }
    }
    Connections
    {
        target: ServiceBluetooth
        function onDeviceListChanged()  { menuBluetooth.scheduleSync() }
        function onNearbyChanged()      { menuBluetooth.scheduleSync() }
        function onEnabledChanged()     { menuBluetooth.scheduleSync() }
    }

    RevealSection
    {
        shown: menuBluetooth.presented
        order: 0

        MenuToggle
        {
            icon: ServiceBluetooth.enabled ? Icon.bluetoothON : Icon.bluetoothOFF
            text: Tr.tr("common.bluetooth")

            enabled: ServiceBluetooth.available
            checked: ServiceBluetooth.enabled

            onToggle: value => ServiceBluetooth.setEnabled(value)
        }

        MenuLabel
        {
            hint: true
            visible: !ServiceBluetooth.enabled
            text: ServiceBluetooth.available ? Tr.tr("menu.bluetooth.off") : Tr.tr("common.noBluetoothAdapter")
        }
    }

    RevealSection
    {
        shown: menuBluetooth.presented
        order: 1

        MenuSeparator { visible: ServiceBluetooth.enabled }

        MenuLabel { visible: connectedModel.count > 0; text: Tr.tr("common.connected") }

        MenuList
        {
            model: connectedModel
            maxHeight: Math.round(3 * 60 * Config.themeScale)
            opening: menuBluetooth.opening

            delegate: DeviceRow
            {
                id: connectedRow
                MenuRowAction { enabled: !connectedRow.working; icon: Icon.linkOff; label: Tr.tr("common.disconnect"); onClicked: ServiceBluetooth.disconnect(connectedRow.address) }
                MenuRowAction { enabled: !connectedRow.working; icon: Icon.trash; label: Tr.tr("common.forget"); danger: true; onClicked: ServiceBluetooth.forget(connectedRow.address) }
            }
        }
    }

    RevealSection
    {
        shown: menuBluetooth.presented
        order: 2

        MenuLabel { visible: pairedModel.count > 0; text: Tr.tr("menu.bluetooth.devices") }
        MenuLabel { hint: true; visible: ServiceBluetooth.enabled && connectedModel.count === 0 && pairedModel.count === 0; text: Tr.tr("menu.bluetooth.noPaired") }

        MenuList
        {
            model: pairedModel
            maxHeight: Math.round(4 * 44 * Config.themeScale)
            opening: menuBluetooth.opening

            delegate: DeviceRow
            {
                id: pairedRow
                MenuRowAction { enabled: !pairedRow.working; icon: Icon.trash; label: Tr.tr("common.forget"); danger: true; onClicked: ServiceBluetooth.forget(pairedRow.address) }
            }
        }
    }

    RevealSection
    {
        shown: menuBluetooth.presented
        order: 3

        MenuSeparator { visible: ServiceBluetooth.enabled }

        MenuLabel
        {
            visible: ServiceBluetooth.enabled
            text: Tr.tr("menu.bluetooth.nearby")
            actionText: ServiceBluetooth.discovering ? Tr.tr("common.cancel") : Tr.tr("common.search")
            actionIcon: ServiceBluetooth.discovering ? Icon.close : Icon.reload
            onActionTriggered:
            {
                menuBluetooth.startedScan = !ServiceBluetooth.discovering;
                ServiceBluetooth.setDiscovering(!ServiceBluetooth.discovering);
            }
        }

        MenuLabel
        {
            hint: true
            visible: ServiceBluetooth.enabled && nearbyModel.count === 0
            text: ServiceBluetooth.discovering ? Tr.tr("menu.bluetooth.searching") : Tr.tr("menu.bluetooth.noNearby")
        }

        MenuList
        {
            model: nearbyModel
            opening: menuBluetooth.opening
            maxHeight: Math.round(4 * 44 * Config.themeScale)

            delegate: MenuRow
            {
                required property string address
                required property string name
                required property string kind
                required property bool   working

                icon: Icon.bluetoothDevice(kind)
                text: name
                subtitle: working ? Tr.tr("menu.bluetooth.pairing") : Tr.tr("menu.bluetooth.clickToPair")
                busy: working

                onClicked: ServiceBluetooth.activate(ServiceBluetooth.deviceBy(address))
            }
        }
    }

    component DeviceRow: MenuRow
    {
        required property string address
        required property string name
        required property string kind
        required property string statusKey
        required property bool   connected
        required property bool   working
        required property real   battery

        icon: Icon.bluetoothDevice(kind)
        text: name
        subtitle: working || battery < 0 ? statusKey !== "" ? Tr.tr(statusKey) : "" : Math.round(battery * 100) + "%"
        level: battery
        selected: connected
        prominent: connected
        busy: working

        onClicked: ServiceBluetooth.activate(ServiceBluetooth.deviceBy(address))
    }
}
