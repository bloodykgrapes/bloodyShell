import QtQuick

import "../../../../common"
import "../../../../core"

Item
{
    id: settingsRow

    property string icon: ""
    property string label: ""
    property string description: ""
    property string valueText: ""

    property bool stacked: false
    property bool pending: false
    property bool highlighted: false

    property string badge: pending ? Tr.tr("common.notConnected") : ""
    property color  badgeColor: "transparent"

    default property alias control: slot.data

    readonly property int inset: Theme.settingsRowInset
    readonly property real lead: icon !== "" ? 34 : 0
    readonly property real controlAvailableWidth: Math.max(0, width - inset * 2)
    readonly property real preferredControlWidth: slot.children.reduce((width, child) => child.visible ? Math.max(width, child.implicitWidth || child.width) : width, 0)
    readonly property real valueWidth: valueText !== "" ? Math.min(value.implicitWidth, width * 0.4) : 0
    readonly property bool vertical: stacked || (preferredControlWidth > 0 && controlAvailableWidth - lead - preferredControlWidth - valueWidth - (valueWidth > 0 ? 12 : 0) - Theme.settingsRowGap < Math.min(180, controlAvailableWidth * 0.45))
    readonly property real sideWidth: vertical ? 0 : slot.width + (valueWidth > 0 ? valueWidth + (slot.width > 0 ? 12 : 0) : 0)

    width: parent ? parent.width : 400
    height: vertical
        ? 16 + header.implicitHeight + 12 + slot.height + 16
        : Math.max(Theme.settingsRowHeight, header.implicitHeight + 28, slot.height + 24)

    HoverHandler { id: hover }
    SettingsTile { row: settingsRow; hovered: settingsRow.highlighted || (hover.hovered && !OverlayState.settingsPopup) }

    Column
    {
        id: header

        x: settingsRow.inset + settingsRow.lead
        y: settingsRow.vertical ? 16 : Math.round((settingsRow.height - implicitHeight) / 2)
        width: Math.max(0, settingsRow.controlAvailableWidth - settingsRow.lead - (settingsRow.sideWidth > 0 ? settingsRow.sideWidth + Theme.settingsRowGap : 0))
        spacing: 4

        Row
        {
            width: parent.width
            spacing: 8

            ShellText
            {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - (badge.visible ? badge.width + parent.spacing : 0))
                label: settingsRow.label
                wrapMode: Text.Wrap
                size: 13
                color: Theme.text1
            }

            Rectangle
            {
                id: badge
                readonly property bool tinted: settingsRow.badgeColor.a > 0

                visible: settingsRow.badge !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(badgeText.implicitWidth + 12, parent.width * 0.45)
                height: badgeText.implicitHeight + 4
                radius: height / 2
                color: tinted ? Qt.rgba(settingsRow.badgeColor.r, settingsRow.badgeColor.g, settingsRow.badgeColor.b, 0.16) : Theme.colorField

                ShellText
                {
                    id: badgeText
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - 12)
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
        ShellText
        {
            width: parent.width
            visible: settingsRow.vertical && !settingsRow.stacked && settingsRow.valueText !== ""
            label: settingsRow.valueText
            size: 12
            color: Theme.text2
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
        width: settingsRow.valueWidth

        visible: !settingsRow.vertical && settingsRow.valueText !== ""
        label: settingsRow.valueText
        size: 12
        color: Theme.text2
        horizontalAlignment: Text.AlignRight
    }

    Item
    {
        id: slot

        x: settingsRow.vertical ? settingsRow.inset : settingsRow.width - settingsRow.inset - width
        y: settingsRow.vertical ? header.y + header.implicitHeight + 12 : Math.round((settingsRow.height - height) / 2)
        width: settingsRow.vertical ? settingsRow.controlAvailableWidth : childrenRect.width
        height: childrenRect.height
    }
}
