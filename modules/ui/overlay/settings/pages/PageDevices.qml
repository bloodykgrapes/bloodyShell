import QtQuick
import Quickshell

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageDevices

    onActiveChanged: ServiceDevices.setWatching(pageDevices, active)
    Component.onCompleted: ServiceDevices.setWatching(pageDevices, active)
    Component.onDestruction: ServiceDevices.setWatching(pageDevices, false)

    title: Tr.tr("menu.bluetooth.devices")
    subtitle: Tr.tr("settings.devices.description")

    function themed(names, fallback)
    {
        for (const n of names)
        {
            const found = n ? ServiceAppearance.iconPath(n) : "";
            if (found !== "") return found;
        }
        return fallback;
    }

    function bluetoothStatus(d)
    {
        const parts = [];
        if (d.pairing) parts.push(Tr.tr("menu.bluetooth.pairing"));
        else if (d.connected) parts.push(Tr.tr("common.connected"));
        else parts.push(d.paired ? Tr.tr("menu.bluetooth.paired") : Tr.tr("settings.devices.available"));
        if (d.batteryAvailable) parts.push(Tr.tr("common.battery") + " " + Math.round(d.battery * 100) + "%");
        return parts.join(" · ");
    }

    SettingsGroup
    {
        title: Tr.tr("common.bluetooth")

        SettingsRow
        {
            label: Tr.tr("common.bluetooth")
            description: ServiceBluetooth.available ? "" : Tr.tr("common.noBluetoothAdapter")
            enabled: ServiceBluetooth.available
            Toggle { checked: ServiceBluetooth.enabled; onToggled: value => ServiceBluetooth.setEnabled(value) }
        }
        SettingsRow
        {
            label: Tr.tr("menu.bluetooth.scan")
            description: ServiceBluetooth.discovering ? Tr.tr("settings.devices.pairingHint") : Tr.tr("settings.devices.scanHint")
            enabled: ServiceBluetooth.enabled
            Toggle { checked: ServiceBluetooth.discovering; onToggled: value => ServiceBluetooth.setDiscovering(value) }
        }

        Repeater
        {
            model: ServiceBluetooth.enabled ? ServiceBluetooth.deviceList : []

            SettingsRow
            {
                id: paired

                required property var modelData

                icon: pageDevices.themed([modelData.icon], Icon.bluetoothON)
                label: modelData.name || modelData.address
                description: pageDevices.bluetoothStatus(modelData)

                Row
                {
                    spacing: 6

                    SettingsButton
                    {
                        text: paired.modelData.connected ? Tr.tr("common.disconnect") : Tr.tr("common.connect")
                        onClicked: paired.modelData.connected = !paired.modelData.connected
                    }
                    SettingsIconButton { icon: Icon.trash; onClicked: paired.modelData.forget() }
                }
            }
        }

        Repeater
        {
            model: ServiceBluetooth.enabled && ServiceBluetooth.discovering ? ServiceBluetooth.nearby : []

            SettingsRow
            {
                id: nearby

                required property var modelData

                icon: pageDevices.themed([modelData.icon], Icon.bluetoothON)
                label: modelData.name
                description: modelData.pairing ? Tr.tr("menu.bluetooth.pairing") : Tr.tr("settings.devices.nearby")

                SettingsButton
                {
                    text: nearby.modelData.pairing ? Tr.tr("common.cancel") : Tr.tr("settings.devices.pair")
                    onClicked: nearby.modelData.pairing ? nearby.modelData.cancelPair() : ServiceBluetooth.activate(nearby.modelData)
                }
            }
        }
    }

    function usbSpeed(mbps)
    {
        const v = parseFloat(mbps);
        if (v >= 20000) return "USB 3.2";
        if (v >= 10000) return "USB 3.1";
        if (v >= 5000) return "USB 3.0";
        if (v >= 480) return "USB 2.0";
        return "USB 1.1";
    }

    function usbIcon(d)
    {
        const c = d.classes;
        if (c.indexOf("0e") >= 0) return pageDevices.themed(["camera-web", "camera-video"], Icon.settingsDevices);
        if (c.indexOf("08") >= 0) return pageDevices.themed(["drive-removable-media-usb", "drive-removable-media"], Icon.settingsStorage);
        if (c.indexOf("01") >= 0) return pageDevices.themed(["audio-headset", "audio-card"], Icon.speaker);
        if (c.indexOf("07") >= 0) return pageDevices.themed(["printer"], Icon.settingsDevices);
        if (c.indexOf("e0") >= 0) return pageDevices.themed(["bluetooth"], Icon.bluetoothON);
        if (c.indexOf("03") >= 0) return pageDevices.themed([d.protocols.indexOf("1") >= 0 ? "input-keyboard" : "input-mouse"], Icon.settingsDevices);
        if (/fingerprint/i.test(d.product)) return pageDevices.themed(["fingerprint", "auth-fingerprint"], Icon.userLock);
        return pageDevices.themed(["drive-removable-media-usb", "media-removable"], Icon.settingsDevices);
    }

    SettingsGroup
    {
        title: "USB"

        SettingsRow
        {
            visible: ServiceDevices.usb.length === 0
            label: Tr.tr("settings.devices.noUsbDevices")
        }

        Repeater
        {
            model: ServiceDevices.usb

            SettingsRow
            {
                required property var modelData

                icon: pageDevices.usbIcon(modelData)
                label: modelData.product
                description: [modelData.maker.replace(/\s*(Co\.,\s*)?Ltd\.?$/i, "").replace(/,\s*Inc\.?$/i, ""), pageDevices.usbSpeed(modelData.speed)].filter(s => s).join(" · ")
                valueText: modelData.id
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.devices.printers")

        SettingsRow
        {
            visible: ServiceDevices.printerState !== "ok" || ServiceDevices.printers.length === 0
            label: ServiceDevices.printerState === "missing" ? Tr.tr("settings.devices.printingUnavailable")
                 : ServiceDevices.printerState === "stopped" ? Tr.tr("settings.devices.printingStopped")
                 : ServiceDevices.printerState === "loading" ? Tr.tr("settings.devices.searchingPrinters") : Tr.tr("settings.devices.noPrinters")
            description: ServiceDevices.printerState === "missing" ? Tr.tr("settings.devices.cupsMissing")
                       : ServiceDevices.printerState === "stopped" ? Tr.tr("settings.devices.startPrintingHint") : ""
        }

        Repeater
        {
            model: ServiceDevices.printers

            SettingsRow
            {
                id: printer

                required property var modelData
                readonly property bool isDefault: modelData.name === ServiceDevices.printerDefault

                icon: pageDevices.themed(["printer"], Icon.settingsDevices)
                label: modelData.name.replace(/_/g, " ")
                description: modelData.status + (isDefault ? " · default" : "")

                SettingsButton
                {
                    visible: !printer.isDefault
                    text: Tr.tr("settings.devices.setAsDefault")
                    onClicked: ServiceDevices.setDefaultPrinter(printer.modelData.name)
                }
            }
        }

        SettingsRow
        {
            visible: ServiceDevices.printerState === "ok"
            label: Tr.tr("settings.devices.addPrinter")
            description: Tr.tr("settings.devices.printerSetupHint")

            SettingsButton
            {
                text: Tr.tr("common.add")
                icon: Icon.add
                onClicked: ServiceDevices.addPrinter()
            }
        }
    }

}
