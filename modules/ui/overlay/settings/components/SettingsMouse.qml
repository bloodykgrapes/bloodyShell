import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"

SettingsGroup
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
        SettingsChoices
        {
            objectName: mouseSettings.namePrefix + "Acceleration"
            options: [{label: Tr.tr("common.off"), value: "flat"}, {label: Tr.tr("settings.devices.adaptive"), value: "adaptive"}]
            current: ServiceDevices.mouse.profile
            onSelected: value => ServiceDevices.setMouse("profile", value)
        }
    }
    SettingsRow
    {
        visible: mouseSettings.advanced
        label: Tr.tr("settings.devices.primaryButton")
        enabled: mouseSettings.available
        SettingsChoices
        {
            objectName: mouseSettings.namePrefix + "PrimaryButton"
            options: [{label: Tr.tr("settings.devices.leftButton"), value: false}, {label: Tr.tr("settings.devices.rightButton"), value: true}]
            current: ServiceDevices.mouse.leftHanded
            onSelected: value => ServiceDevices.setMouse("leftHanded", value)
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
}
