import QtQuick

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"

Rectangle
{
    id: card

    required property var windowData
    property bool selected: false
    property bool hovered: false
    property bool pressed: false
    radius: Math.max(0, Theme.radiusLarge - 3)
    color: selected ? Theme.colorRaised : Theme.colorSolid
    border.width: 1
    border.color: selected ? Theme.colorAccent : Theme.colorHairline
    Tint on color {}
    Tint on border.color {}

    Rectangle
    {
        anchors { fill: parent; margins: 1 }
        radius: Math.max(0, card.radius - 1)
        color: card.pressed ? Theme.colorPressed : Theme.colorHoverStrong
        opacity: card.pressed || card.hovered ? 1 : 0
        Smooth on opacity {}
        Tint on color {}
    }

    ShellIcon
    {
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -24 }
        icon: ServiceApplications.iconFor(card.windowData.app_id)
        size: 56
    }
    Column
    {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 18 }
        spacing: 4
        ShellText
        {
            width: parent.width
            label: ServiceApplications.appName(card.windowData.app_id, card.windowData.app_id)
            size: 13
            font.weight: Font.DemiBold
            color: Theme.text1
        }
        ShellText { width: parent.width; label: card.windowData.title; size: 11; color: Theme.text2 }
    }
}
