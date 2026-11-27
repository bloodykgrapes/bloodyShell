pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    id: pageShortcuts

    title: Tr.tr("settings.structure.shortcuts")
    subtitle: Tr.tr("settings.shortcuts.description")

    readonly property var sections:
    [
        {
            id: "windows", title: Tr.tr("settings.shortcuts.windowManagement"), bindings: [
                { keys: ["Super", "Tab"], action: Tr.tr("settings.shortcuts.overview") },
                { keys: ["Super", Tr.tr("settings.shortcuts.arrows")], action: Tr.tr("settings.shortcuts.focus") },
                { keys: ["Super", "1–9"], action: Tr.tr("settings.shortcuts.focusWorkspace") },
                { keys: ["Super", "Ctrl", Tr.tr("settings.shortcuts.arrows")], action: Tr.tr("settings.shortcuts.focusMonitor") },
                { keys: ["Super", "Shift", Tr.tr("settings.shortcuts.arrows")], action: Tr.tr("settings.shortcuts.moveWindow") },
                { keys: ["Super", "Shift", "1–9"], action: Tr.tr("settings.shortcuts.moveToWorkspace") },
                { keys: ["Super", "Shift", "Ctrl", Tr.tr("settings.shortcuts.arrows")], action: Tr.tr("settings.shortcuts.moveToMonitor") },
                { keys: ["Super", "[ / ]"], action: Tr.tr("settings.shortcuts.consumeOrExpel") },
                { keys: ["Super", "Q"], action: Tr.tr("settings.shortcuts.closeWindow") },
                { keys: ["Super", "R"], action: Tr.tr("settings.shortcuts.nextWidth") },
                { keys: ["Super", "M"], action: Tr.tr("settings.shortcuts.maximizeWindow") },
                { keys: ["Super", "F"], action: Tr.tr("settings.shortcuts.maximizeColumn") },
                { keys: ["Super", "Shift", "F"], action: Tr.tr("settings.shortcuts.fullscreen") },
                { keys: ["Alt", "Tab"], action: Tr.tr("settings.shortcuts.nextWindow") }
            ]
        },
        {
            id: "special", title: Tr.tr("settings.shortcuts.special"), bindings: [
                { keys: ["Print"], action: Tr.tr("settings.shortcuts.screenshot") },
                { keys: ["Super", "Shift", "S"], action: Tr.tr("settings.shortcuts.screenshot") },
                { keys: ["Super", "L"], action: Tr.tr("settings.shortcuts.lock") }
            ]
        },
        {
            id: "applications", title: Tr.tr("settings.shortcuts.applicationsOverlays"), bindings: [
                { keys: ["Super", "W"], action: Tr.tr("settings.shortcuts.browser") },
                { keys: ["Super", "E"], action: Tr.tr("settings.shortcuts.files") },
                { keys: ["Super", "T"], action: Tr.tr("settings.shortcuts.terminal") },
                { keys: ["Super", "D"], action: Tr.tr("common.launcher") },
                { keys: ["Super", "Y"], action: Tr.tr("common.wallpapers") },
                { keys: ["Super", "I"], action: Tr.tr("common.settings") },
                { keys: ["Super", "P"], action: Tr.tr("settings.shortcuts.powerMenu") }
            ]
        },
        {
            id: "advanced", title: Tr.tr("settings.shortcuts.advanced"), bindings: [
                { keys: ["Ctrl", "Alt", "Del"], action: Tr.tr("settings.shortcuts.quit") }
            ]
        }
    ]

    ShellText
    {
        width: parent.width
        label: Tr.tr("settings.shortcuts.installHint")
        size: 12
        color: Theme.text3
        wrapMode: Text.Wrap
    }

    Repeater
    {
        model: pageShortcuts.sections

        SettingsRowGroup
        {
            id: section
            required property var modelData
            objectName: "shortcuts-" + modelData.id
            title: modelData.title

            Item
            {
                width: parent.width
                height: keyHeading.implicitHeight + 8
                visible: width >= 440

                ShellText
                {
                    id: keyHeading
                    x: Theme.settingsRowInset
                    width: (parent.width - Theme.settingsRowInset * 2 - 16) * 0.54
                    label: Tr.tr("settings.shortcuts.key")
                    size: 11
                    color: Theme.text3
                }
                ShellText
                {
                    x: keyHeading.x + keyHeading.width + 16
                    width: Math.max(0, parent.width - x - Theme.settingsRowInset)
                    label: Tr.tr("settings.shortcuts.action")
                    size: 11
                    color: Theme.text3
                }
            }

            Column
            {
                width: parent.width
                spacing: 1

                Repeater
                {
                    model: section.modelData.bindings

                    ShortcutRow
                    {
                        required property var modelData
                        keys: modelData.keys
                        label: modelData.action
                    }
                }
            }
        }
    }

    component ShortcutRow: Item
    {
        id: shortcutRow
        property var keys: []
        property string label: ""
        readonly property bool stacked: width < 440
        readonly property real innerWidth: Math.max(0, width - Theme.settingsRowInset * 2)

        width: parent ? parent.width : 0
        height: Math.max(56, (stacked ? caps.implicitHeight + 10 + action.implicitHeight : Math.max(caps.implicitHeight, action.implicitHeight)) + 24)
        Accessible.role: Accessible.StaticText
        Accessible.name: keys.join(" + ") + ": " + label

        HoverHandler { id: hover }
        SettingsTile { row: shortcutRow; hovered: hover.hovered && !OverlayState.settingsPopup }

        Flow
        {
            id: caps
            x: Theme.settingsRowInset
            y: shortcutRow.stacked ? 12 : Math.round((shortcutRow.height - implicitHeight) / 2)
            width: shortcutRow.stacked ? shortcutRow.innerWidth : Math.max(0, (shortcutRow.innerWidth - 16) * 0.54)
            spacing: 6

            Repeater
            {
                model: shortcutRow.keys

                Row
                {
                    id: keyPart
                    required property string modelData
                    required property int index
                    spacing: 6

                    ShellText
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: keyPart.index > 0
                        label: "+"
                        size: 11
                        color: Theme.text3
                    }
                    Rectangle
                    {
                        width: Math.min(keyName.implicitWidth + 16, Math.max(0, caps.width - (keyPart.index > 0 ? 14 : 0)))
                        height: keyName.implicitHeight + 10
                        radius: Theme.radiusSmall
                        color: Theme.controlColorActive

                        ShellText
                        {
                            id: keyName
                            x: 8; y: 5
                            width: Math.max(0, parent.width - 16)
                            label: keyPart.modelData
                            size: 11
                            font.family: Theme.fontMono
                            color: Theme.text1
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }

        ShellText
        {
            id: action
            x: shortcutRow.stacked ? Theme.settingsRowInset : caps.x + caps.width + 16
            y: shortcutRow.stacked ? caps.y + caps.implicitHeight + 10 : Math.round((shortcutRow.height - implicitHeight) / 2)
            width: Math.max(0, shortcutRow.width - x - Theme.settingsRowInset)
            label: shortcutRow.label
            size: 13
            color: Theme.text1
            wrapMode: Text.Wrap
        }
    }
}
