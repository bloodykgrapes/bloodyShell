import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Item
{
    id: settingsTab

    property string icon: ""
    property string title: ""
    property bool   selected: false

    signal clicked()

    readonly property bool hovered: area.containsMouse

    width: parent ? parent.width : 200
    height: 32

    scale: area.pressed ? 0.97 : area.containsMouse ? 1.03 : 1
    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.radiusLarge - 2

        color: Theme.colorHover
        opacity: area.containsMouse && !settingsTab.selected ? 1 : 0
        Smooth on opacity { duration: 160 }
    }

    Row
    {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 11

        ShellIcon
        {
            anchors.verticalCenter: parent.verticalCenter
            icon: settingsTab.icon
            size: 16
            zoom: 1.05
            opacity: settingsTab.selected ? 1 : 0.85
            Smooth on opacity { duration: 200 }
        }
        ShellText
        {
            anchors.verticalCenter: parent.verticalCenter
            label: settingsTab.title
            size: 13
            color: settingsTab.selected ? Theme.text1 : Theme.text2
            Tint on color { duration: 200 }
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: settingsTab.clicked()
    }
}
