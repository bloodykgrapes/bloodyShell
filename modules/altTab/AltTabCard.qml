import QtQuick
import Quickshell.Widgets

import "../components"
import "../core"
import "../services"

ClippingRectangle
{
    id: card

    required property var windowData
    radius: Math.max(0, Theme.radiusLarge - 3)
    color: Theme.colorRaised
    border.width: 1
    border.color: Theme.colorHairline

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
