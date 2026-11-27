import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"

SettingsRowGroup
{
    id: mouseSettings
    visible: ServiceCompositor.supports("mouse")

    property bool advanced: true
    property string namePrefix: "mouse"
    readonly property bool available: ServiceDevices.mouseLoaded && ServiceDevices.mouseAvailable

    title: Tr.tr("settings.devices.mouse")

    SettingsRow
    {
        visible: !ServiceDevices.mouseLoaded || !ServiceDevices.mouseAvailable || ServiceDevices.mouseError !== ""
        label: ServiceDevices.mouseLoaded ? Tr.tr("settings.devices.mouseUnavailable") : Tr.tr("common.loading")
        description: ServiceDevices.mouseError
    }
    SettingsRow
    {
        label: Tr.tr("settings.devices.pointerSpeed")
        enabled: mouseSettings.available
        SettingsSlider
        {
            objectName: mouseSettings.namePrefix + "PointerSpeed"
            from: -1; to: 1; step: 0.05
            value: ServiceDevices.mouse.speed
            onMoved: value => ServiceDevices.setMouse("speed", value)
        }
    }
    SettingsRow
    {
        label: Tr.tr("settings.devices.acceleration")
        enabled: mouseSettings.available
        Toggle
        {
            objectName: mouseSettings.namePrefix + "Acceleration"
            checked: ServiceDevices.mouse.profile === "adaptive"
            onToggled: value => ServiceDevices.setMouse("profile", value ? "adaptive" : "flat")
        }
    }
    SettingsRow
    {
        label: Tr.tr("settings.devices.leftHanded")
        description: Tr.tr("settings.devices.leftHandedHint")
        enabled: mouseSettings.available
        Toggle
        {
            objectName: mouseSettings.namePrefix + "LeftHanded"
            checked: ServiceDevices.mouse.leftHanded
            onToggled: value => ServiceDevices.setMouse("leftHanded", value)
        }
    }
    SettingsRow
    {
        label: Tr.tr("settings.devices.naturalScroll")
        enabled: mouseSettings.available
        Toggle { objectName: mouseSettings.namePrefix + "NaturalScroll"; checked: ServiceDevices.mouse.naturalScroll; onToggled: value => ServiceDevices.setMouse("naturalScroll", value) }
    }
    SettingsRow
    {
        label: Tr.tr("settings.devices.verticalScrollSpeed")
        enabled: mouseSettings.available
        SettingsStepper
        {
            objectName: mouseSettings.namePrefix + "VerticalScrollSpeed"
            from: 0.1; to: 10; step: 0.1; decimals: 1; suffix: "×"
            value: Math.abs(ServiceDevices.mouse.scrollVertical)
            onEdited: value => ServiceDevices.setMouse("scrollVertical", value * (ServiceDevices.mouse.scrollVertical < 0 ? -1 : 1))
        }
    }
    SettingsRow
    {
        visible: mouseSettings.advanced
        label: Tr.tr("settings.devices.horizontalScrollSpeed")
        enabled: mouseSettings.available
        SettingsStepper
        {
            objectName: mouseSettings.namePrefix + "HorizontalScrollSpeed"
            from: 0.1; to: 10; step: 0.1; decimals: 1; suffix: "×"
            value: Math.abs(ServiceDevices.mouse.scrollHorizontal)
            onEdited: value => ServiceDevices.setMouse("scrollHorizontal", value * (ServiceDevices.mouse.scrollHorizontal < 0 ? -1 : 1))
        }
    }
    SettingsRow
    {
        visible: mouseSettings.advanced
        label: Tr.tr("settings.devices.middleEmulation")
        description: Tr.tr("settings.devices.middleEmulationHint")
        enabled: mouseSettings.available
        Toggle { objectName: mouseSettings.namePrefix + "MiddleEmulation"; checked: ServiceDevices.mouse.middleEmulation; onToggled: value => ServiceDevices.setMouse("middleEmulation", value) }
    }
    SettingsRow
    {
        visible: mouseSettings.advanced
        label: Tr.tr("settings.devices.scrollMethod")
        enabled: mouseSettings.available
        SettingsDropdown
        {
            objectName: mouseSettings.namePrefix + "ScrollMethod"
            options: [
                {label: Tr.tr("settings.devices.deviceDefault"), value: ""},
                {label: Tr.tr("settings.devices.wheelOnly"), value: "no-scroll"},
                {label: Tr.tr("settings.devices.buttonScrolling"), value: "on-button-down"},
                {label: Tr.tr("settings.devices.twoFingerScrolling"), value: "two-finger"},
                {label: Tr.tr("settings.devices.edgeScrolling"), value: "edge"}
            ]
            current: ServiceDevices.mouse.scrollMethod
            onSelected: value => ServiceDevices.setMouse("scrollMethod", value)
        }
    }
    SettingsRow
    {
        visible: mouseSettings.advanced && ServiceDevices.mouse.scrollMethod === "on-button-down"
        label: Tr.tr("settings.devices.scrollButton")
        enabled: mouseSettings.available
        SettingsDropdown
        {
            objectName: mouseSettings.namePrefix + "ScrollButton"
            readonly property var buttons: [
                {label: Tr.tr("settings.devices.deviceDefault"), value: -1},
                {label: Tr.tr("settings.devices.middleButton"), value: 274},
                {label: Tr.tr("settings.devices.rightButton"), value: 273},
                {label: Tr.tr("settings.devices.leftButton"), value: 272},
                {label: Tr.tr("settings.devices.sideButton1"), value: 275},
                {label: Tr.tr("settings.devices.sideButton2"), value: 276}
            ]
            options: buttons.some(button => button.value === current) ? buttons
                : buttons.concat([{label: Tr.tr("settings.devices.customButton").arg(current), value: current}])
            current: ServiceDevices.mouse.scrollButton
            onSelected: value => ServiceDevices.setMouse("scrollButton", value)
        }
    }
    SettingsRow
    {
        visible: mouseSettings.advanced && ServiceDevices.mouse.scrollMethod === "on-button-down"
        label: Tr.tr("settings.devices.buttonScrollMode")
        enabled: mouseSettings.available
        SettingsDropdown
        {
            objectName: mouseSettings.namePrefix + "ButtonScrollMode"
            options: [
                {label: Tr.tr("settings.devices.holdButton"), value: false},
                {label: Tr.tr("settings.devices.toggleButton"), value: true}
            ]
            current: ServiceDevices.mouse.scrollButtonLock
            onSelected: value => ServiceDevices.setMouse("scrollButtonLock", value)
        }
    }
}
