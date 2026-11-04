import QtQuick

import ".."
import "../../core"

Item
{
    id: settingsRow

    property string icon: ""
    property string label: ""
    property string description: ""
    property string valueText: ""

    property bool stacked: false
    property bool pending: false

    property string badge: pending ? Tr.tr("settings.notConnected") : ""
    property color  badgeColor: "transparent"

    default property alias control: slot.data

    readonly property int  inset: 18
    readonly property real lead: icon !== "" ? 34 : 0
    readonly property real sideWidth: stacked ? 0 : slot.width + (value.visible ? value.implicitWidth + 12 : 0)

    width: parent ? parent.width : 400
    height: stacked
        ? 14 + header.implicitHeight + 10 + slot.height + 14
        : Math.max(56, header.implicitHeight + 24, slot.height + 20)

    HoverHandler { id: hover }
    SettingsTile { row: settingsRow; hovered: hover.hovered && !OverlayState.settingsPopup }

    Column
    {
        id: header

        x: settingsRow.inset + settingsRow.lead
        y: settingsRow.stacked ? 14 : Math.round((settingsRow.height - implicitHeight) / 2)
        width: Math.max(80, settingsRow.width - settingsRow.inset * 2 - settingsRow.lead - (settingsRow.sideWidth > 0 ? settingsRow.sideWidth + 20 : 0))
        spacing: 3

        Row
        {
            spacing: 8

            ShellText
            {
                anchors.verticalCenter: parent.verticalCenter
                label: settingsRow.label
                size: 13
                color: Theme.text1
            }

            Rectangle
            {
                readonly property bool tinted: settingsRow.badgeColor.a > 0

                visible: settingsRow.badge !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: badgeText.implicitWidth + 12
                height: badgeText.implicitHeight + 4
                radius: height / 2
                color: tinted ? Qt.rgba(settingsRow.badgeColor.r, settingsRow.badgeColor.g, settingsRow.badgeColor.b, 0.16) : Theme.colorField

                ShellText
                {
                    id: badgeText
                    anchors.centerIn: parent
                    label: settingsRow.badge
                    size: 9
                    color: parent.tinted ? settingsRow.badgeColor : Theme.text3
                }
            }
        }

        ShellText
        {
            width: parent.width
            label: settingsRow.description
            size: 11
            color: Theme.text3
            wrapMode: Text.Wrap
        }
    }

    ShellIcon
    {
        visible: settingsRow.icon !== ""
        x: settingsRow.inset
        y: header.y + Math.round((Math.min(header.implicitHeight, 40) - height) / 2)
        icon: settingsRow.icon
        size: 22
    }

    ShellText
    {
        id: value

        anchors.verticalCenter: slot.verticalCenter
        x: slot.x - (slot.width > 0 ? 12 : 0) - width
        width: Math.min(implicitWidth, settingsRow.width * 0.45)

        visible: !settingsRow.stacked && settingsRow.valueText !== ""
        label: settingsRow.valueText
        size: 12
        color: Theme.text2
        horizontalAlignment: Text.AlignRight
    }

    Item
    {
        id: slot

        x: settingsRow.stacked ? settingsRow.inset : settingsRow.width - settingsRow.inset - width
        y: settingsRow.stacked ? header.y + header.implicitHeight + 10 : Math.round((settingsRow.height - height) / 2)
        width: settingsRow.stacked ? settingsRow.width - settingsRow.inset * 2 : childrenRect.width
        height: childrenRect.height
    }
}
