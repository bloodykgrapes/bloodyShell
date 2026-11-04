import QtQuick
import Quickshell

import "../../../components/settings"
import "../../../core"

SettingsPage
{
    id: pageBar

    title: Tr.tr("common.bar")
    subtitle: Tr.tr("settings.bar.stylePositionWidgetOrderHint")

    readonly property var zones: [{ zone: "bar1", title: Tr.tr("settings.bar.start") }, { zone: "bar2", title: Tr.tr("settings.bar.center") }, { zone: "bar3", title: Tr.tr("settings.bar.end") }]

    SettingsGroup
    {
        SettingsRow
        {
            label: Tr.tr("common.enabled")
            SettingsSwitch { checked: Config.barEnabled; onToggled: value => Config.set("barEnabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.position")
            SettingsChoices
            {
                options: [{ label: Tr.tr("common.top"), value: Enums.EdgeTop }, { label: Tr.tr("common.bottom"), value: Enums.EdgeBottom }, { label: Tr.tr("common.left"), value: Enums.EdgeLeft }, { label: Tr.tr("common.right"), value: Enums.EdgeRight }]
                current: Config.barSide
                onSelected: value => Config.set("barSide", value)
            }
        }
        SettingsRow
        {
            visible: Quickshell.screens.length > 1
            label: Tr.tr("common.monitors")
            stacked: true
            SettingsToggles
            {
                options: Quickshell.screens.map(m => ({ label: m.name, value: m.name }))
                checked: Config.screensShown("barScreens")
                onToggled: (value, on) => Config.toggleScreen("barScreens", value, on)
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.hiding")

        SettingsRow
        {
            label: Tr.tr("common.autoHide")
            description: Tr.tr("common.slidesAwayUntilThe")
            SettingsSwitch { checked: Config.barHideAuto; onToggled: value => Config.set("barHideAuto", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.showOnEmptyWorkspace")
            description: Tr.tr("common.keepsVisibleWhileThe")
            visible: Config.barHideAuto
            SettingsSwitch { checked: Config.barHideSmart; onToggled: value => Config.set("barHideSmart", value) }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.style")

        SettingsRow
        {
            label: Tr.tr("common.bar")
            description: Tr.tr("settings.bar.defaultAStripAlongHint")
            stacked: true

            Row
            {
                spacing: 10
                Repeater
                {
                    model: [{ label: Tr.tr("common.default"), value: Enums.BarDefault }, { label: Tr.tr("settings.bar.frame"), value: Enums.BarFrame }, { label: Tr.tr("common.floating"), value: Enums.BarFloating }, { label: Tr.tr("settings.bar.islands"), value: Enums.BarIslands }]

                    SettingsStyleCard
                    {
                        required property var modelData
                        kind: "bar"
                        value: modelData.value
                        label: modelData.label
                        width: 150
                        current: Config.barType === modelData.value
                        onClicked: Config.set("barType", modelData.value)
                    }
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.bar.menu")
            description: Tr.tr("settings.bar.styleForMenuAttachedHint")
            stacked: true

            Row
            {
                spacing: 10
                Repeater
                {
                    model: [{ label: Tr.tr("common.attached"), value: Enums.MenuAttached }, { label: Tr.tr("common.floating"), value: Enums.MenuFloating }]

                    SettingsStyleCard
                    {
                        required property var modelData
                        kind: "menu"
                        value: modelData.value
                        label: modelData.label
                        current: Config.barMenu === modelData.value
                        onClicked: Config.set("barMenu", modelData.value)
                    }
                }
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.bar.widgetOrder")
        subtitle: Tr.tr("settings.bar.islandsAreMadeFromHint")

        Repeater
        {
            model: pageBar.zones

            SettingsLayoutEditor
            {
                required property var modelData

                zone: modelData.zone
                heading: modelData.title
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.bar.widgets")

        SettingsRow
        {
            label: Tr.tr("settings.bar.sharedBackground")
            description: Tr.tr("settings.bar.highlightedWidgetsSitOnHint")
            stacked: true

            SettingsToggles
            {
                options: Object.keys(Registry.widgets).filter(id => !Registry.widgets[id].hidden).map(id => ({ label: Registry.widgets[id].title, value: id }))
                checked: Config.barHighlight
                onToggled: (value, on) => Config.set("barHighlight", on ? Config.barHighlight.concat([value]) : Config.barHighlight.filter(v => v !== value))
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.bar.batteryPercentage")
            description: Tr.tr("settings.bar.shownNextToThe")
            SettingsSwitch { checked: Config.barWidgetBatteryValue; onToggled: value => Config.set("barWidgetBatteryValue", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.windowTitle")
            SettingsChoices
            {
                options: [{ label: Tr.tr("settings.bar.title"), value: false }, { label: Tr.tr("settings.bar.appId"), value: true }]
                current: Config.barWidgetWindowAppID
                onSelected: value => Config.set("barWidgetWindowAppID", value)
            }
        }
    }
}
