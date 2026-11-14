pragma ComponentBehavior: Bound

import QtQuick

import "../../../common"
import "../../../core"
import "../../../services"
import "../settings/components"

Column
{
    id: input

    width: parent ? parent.width : 600
    spacing: 20
    property string newLayout: ""
    property string newVariant: ""
    readonly property var variants: [{label: Tr.tr("common.default"), value: ""}].concat(
        (ServiceKeyboard.variants[newLayout] || []).map(variant => ({label: variant.name, value: variant.code})))

    RenderActivity
    {
        id: activity
        target: input
        onActiveChanged: ServiceDevices.setMouseWatching(input, active)
    }
    Component.onCompleted: { ServiceKeyboard.refresh(); ServiceDevices.setMouseWatching(input, activity.active); }
    Component.onDestruction: ServiceDevices.setMouseWatching(input, false)

    SettingsGroup
    {
        title: Tr.tr("settings.timeLanguage.keyboardLayouts")
        visible: ServiceCompositor.supports("keyboard")
        subtitle: Tr.tr("settings.timeLanguage.layoutsHint")
        SettingsRow
        {
            visible: ServiceKeyboard.error !== ""
            label: Tr.tr("common.actionFailed")
            description: ServiceKeyboard.error
            badge: Tr.tr("common.error")
            badgeColor: Theme.colorCritical
        }
        Repeater
        {
            model: ServiceKeyboard.layouts
            SettingsRow
            {
                id: layout
                required property var modelData
                required property int index
                label: ServiceKeyboard.title(modelData)
                description: modelData.layout + (modelData.variant ? " · " + modelData.variant : "") + (index === 0 ? " · " + Tr.tr("common.default") : "")
                Row
                {
                    spacing: 6
                    SettingsIconButton
                    {
                        objectName: "helperLayoutPrimary-" + layout.index
                        text: Tr.tr("helper.makePrimary")
                        icon: Icon.chevronUp
                        enabled: layout.index > 0
                        onClicked: ServiceKeyboard.moveLayout(layout.index, -layout.index)
                    }
                    SettingsIconButton
                    {
                        objectName: "helperLayoutRemove-" + layout.index
                        text: Tr.tr("helper.removeLayout")
                        icon: Icon.close
                        enabled: ServiceKeyboard.layouts.length > 1
                        onClicked: ServiceKeyboard.removeLayout(layout.index)
                    }
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.addLayout")
            stacked: true
            enabled: ServiceKeyboard.loaded
            Flow
            {
                width: parent.width
                spacing: 8
                SettingsCombo
                {
                    objectName: "helperLayoutChoice"
                    preferredWidth: 220
                    options: ServiceKeyboard.catalog.map(layout => ({label: layout.name, value: layout.code}))
                    placeholderText: Tr.tr("common.keyboardLayout")
                    current: input.newLayout
                    onSelected: value => { input.newLayout = value; input.newVariant = ""; }
                }
                SettingsCombo
                {
                    objectName: "helperLayoutVariant"
                    preferredWidth: 220
                    options: input.variants
                    current: input.newVariant
                    enabled: input.newLayout !== "" && input.variants.length > 1
                    onSelected: value => input.newVariant = value
                }
                SettingsButton
                {
                    objectName: "helperLayoutAdd"
                    icon: Icon.add
                    text: Tr.tr("common.add")
                    enabled: input.newLayout !== "" && !ServiceKeyboard.layouts.some(layout => layout.layout === input.newLayout && layout.variant === input.newVariant)
                    onClicked: { ServiceKeyboard.addLayout(input.newLayout, input.newVariant); input.newLayout = ""; input.newVariant = ""; }
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.layoutShortcut")
            enabled: ServiceKeyboard.loaded && ServiceKeyboard.layouts.length > 1
            SettingsCombo
            {
                objectName: "helperLayoutShortcut"
                options: Registry.layoutShortcutOptions
                current: ServiceKeyboard.switchOption
                onSelected: value => ServiceKeyboard.set("switchOption", value)
            }
        }
    }

    SettingsMouse { advanced: false; namePrefix: "helperMouse" }
}
