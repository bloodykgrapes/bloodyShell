pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageDevices

    onActiveChanged:
    {
        ServiceDevices.setWatching(pageDevices, active);
        ServiceDevices.setTouchpadWatching(pageDevices, active);
    }
    Component.onCompleted:
    {
        ServiceDevices.setWatching(pageDevices, active);
        ServiceDevices.setTouchpadWatching(pageDevices, active);
        ServiceKeyboard.refresh();
    }
    Component.onDestruction:
    {
        ServiceDevices.setWatching(pageDevices, false);
        ServiceDevices.setTouchpadWatching(pageDevices, false);
    }

    title: Tr.tr("settings.devices.title")
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
        if (c.indexOf("07") >= 0) return pageDevices.themed(["printer"], Icon.printer);
        if (c.indexOf("e0") >= 0) return pageDevices.themed(["bluetooth"], Icon.bluetoothON);
        if (c.indexOf("03") >= 0) return pageDevices.themed([d.protocols.indexOf("1") >= 0 ? "input-keyboard" : "input-mouse"], d.protocols.indexOf("1") >= 0 ? Icon.keyboard : Icon.mouse);
        if (/fingerprint/i.test(d.product)) return pageDevices.themed(["fingerprint", "auth-fingerprint"], Icon.userLock);
        return pageDevices.themed(["drive-removable-media-usb", "media-removable"], Icon.usb);
    }

    SettingsRowGroup
    {
        objectName: "keyboardOptions"
        title: Tr.tr("settings.devices.keyboard")

        SettingsRow
        {
            label: Tr.tr("settings.devices.repeatDelay")
            description: Tr.tr("settings.devices.repeatDelayHint")
            SettingsStepper
            {
                objectName: "keyboardRepeatDelay"
                value: ServiceKeyboard.repeatDelay
                from: 150; to: 1000; step: 10; suffix: " ms"
                onEdited: value => ServiceKeyboard.set("repeatDelay", Math.round(value))
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.devices.repeatSpeed")
            description: Tr.tr("settings.devices.repeatSpeedHint")
            SettingsStepper
            {
                objectName: "keyboardRepeatSpeed"
                value: ServiceKeyboard.repeatRate
                from: 10; to: 50; step: 1; suffix: "/s"
                onEdited: value => ServiceKeyboard.set("repeatRate", Math.round(value))
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.devices.numLock")
            description: Tr.tr("settings.devices.numLockHint")
            Toggle
            {
                objectName: "keyboardNumLock"
                checked: ServiceKeyboard.numlock
                onToggled: value => ServiceKeyboard.set("numlock", value)
            }
        }
    }

    SettingsMouse { objectName: "mouseOptions"; advanced: false }

    SettingsRowGroup
    {
        objectName: "touchpadOptions"
        title: Tr.tr("settings.devices.trackpad")
        visible: ServiceCompositor.supports("touchpad")

        SettingsRow
        {
            visible: !ServiceDevices.touchpadLoaded || !ServiceDevices.touchpadAvailable || ServiceDevices.touchpadError !== ""
            label: ServiceDevices.touchpadLoaded ? Tr.tr("settings.devices.touchpadUnavailable") : Tr.tr("common.loading")
            description: ServiceDevices.touchpadError
        }
        SettingsRow
        {
            label: Tr.tr("settings.devices.ignoreWhileTyping")
            description: Tr.tr("settings.devices.ignoreWhileTypingHint")
            Toggle
            {
                objectName: "touchpadIgnoreWhileTyping"
                checked: ServiceDevices.touchpad.ignoreWhileTyping
                enabled: ServiceDevices.touchpadLoaded && ServiceDevices.touchpadAvailable
                onToggled: value => ServiceDevices.setTouchpad("ignoreWhileTyping", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.devices.ignoreExternalMouse")
            description: Tr.tr("settings.devices.ignoreExternalMouseHint")
            Toggle
            {
                objectName: "touchpadIgnoreExternalMouse"
                checked: ServiceDevices.touchpad.ignoreExternalMouse
                enabled: ServiceDevices.touchpadLoaded && ServiceDevices.touchpadAvailable
                onToggled: value => ServiceDevices.setTouchpad("ignoreExternalMouse", value)
            }
        }
    }

    SettingsRowGroup
    {
        objectName: "usbDevices"
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

    SettingsRowGroup
    {
        objectName: "printerDevices"
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

                icon: pageDevices.themed(["printer"], Icon.printer)
                label: modelData.name.replace(/_/g, " ")
                description: modelData.status + (isDefault ? " · default" : "")

                Button
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

            Button
            {
                text: Tr.tr("common.add")
                icon: Icon.add
                onClicked: ServiceDevices.addPrinter()
            }
        }
    }
}
