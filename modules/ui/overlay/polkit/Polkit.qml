import QtQuick
import Quickshell

import "../../../common"
import "../../../core"
import ".."
import "../settings/components"

OverlayView
{
    id: polkit

    required property var agent
    readonly property var flow: agent.flow

    name: "polkit"
    onFlowChanged: field.text = ""
    onActiveChanged: if (!active) field.text = ""

    readonly property bool waiting: flow !== null && !flow.isResponseRequired && !flow.isCompleted

    function submit()
    {
        if (!active || !flow || !flow.isResponseRequired) return;
        flow.submit(field.text);
        field.text = "";
    }

    Connections
    {
        target: polkit.flow
        function onIsResponseRequiredChanged() { if (polkit.flow.isResponseRequired) field.grabFocus() }
    }
    Component.onCompleted: Qt.callLater(() => { if (active) field.grabFocus(); })

    Rectangle
    {
        id: card

        anchors.centerIn: parent
        width: Math.min(440, parent.width - 48)
        height: column.implicitHeight + 48
        radius: Theme.settingsRadius
        color: Theme.settingsColorBackground
        border.color: Theme.colorLine
        border.width: Theme.borderWidth

        opacity: polkit.reveal
        scale: 1 - 0.05 * polkit.settle
        transform: Translate { y: polkit.lift }

        MouseArea { anchors.fill: parent }

        Keys.onEscapePressed: polkit.hide()

        Column
        {
            id: column

            x: 24
            y: 24
            width: parent.width - 48
            spacing: 14

            Row
            {
                width: parent.width
                spacing: 12

                Rectangle
                {
                    width: 40
                    height: 40
                    radius: 20
                    color: Theme.colorField

                    ShellIcon { anchors.centerIn: parent; icon: Icon.userLock; size: 18 }
                }
                Column
                {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - 52)
                    spacing: 2

                    ShellText { width: parent.width; label: Tr.tr("polkit.title"); size: 16; color: Theme.text1; font.bold: true }
                    ShellText { width: parent.width; label: Tr.tr("polkit.passwordPrompt").arg(Quickshell.env("USER") || Tr.tr("polkit.currentUser")); size: 11; color: Theme.text3; wrapMode: Text.Wrap }
                }
            }

            ShellText
            {
                width: parent.width
                label: polkit.flow ? polkit.flow.message : ""
                size: 12
                color: Theme.text2
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }

            SettingsInput
            {
                id: field

                width: parent.width
                password: polkit.flow ? !polkit.flow.responseVisible : true
                placeholderText: polkit.flow && polkit.flow.inputPrompt.trim() !== "" ? polkit.flow.inputPrompt.trim().replace(/:$/, "") : Tr.tr("common.password")
                enabled: polkit.active && !polkit.waiting
                onAccepted: polkit.submit()
            }

            ShellText
            {
                width: parent.width
                visible: polkit.flow !== null && polkit.flow.supplementaryMessage !== ""
                label: polkit.flow ? polkit.flow.supplementaryMessage : ""
                size: 11
                color: polkit.flow && polkit.flow.supplementaryIsError ? Theme.colorCritical : Theme.text3
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }

            Item
            {
                width: parent.width
                height: buttons.height

                Row
                {
                    id: buttons
                    anchors.right: parent.right
                    spacing: 8

                    SettingsButton { text: Tr.tr("common.cancel"); onClicked: polkit.hide() }
                    SettingsButton
                    {
                        text: polkit.waiting ? Tr.tr("common.checking") : Tr.tr("polkit.authenticate")
                        icon: Icon.userLock
                        enabled: !polkit.waiting && field.text !== ""
                        onClicked: polkit.submit()
                    }
                }
            }
        }
    }
}
