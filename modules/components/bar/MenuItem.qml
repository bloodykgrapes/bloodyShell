import QtQuick

import ".."
import "../../core"

Item
{
    id: menuItem

    property string icon: ""
    property string text: ""
    property string trailing: ""
    property bool   danger: false

    signal clicked()

    width: parent ? parent.width : 200
    height: 34

    scale: area.pressed ? 0.98 : area.containsMouse ? 1.025 : 1

    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.menuColorHover
        opacity: area.containsMouse ? 1 : 0

        Smooth on opacity {}
    }

    Row
    {
        anchors
        {
            left: parent.left
            right: parent.right

            leftMargin: 10
            rightMargin: 10

            verticalCenter: parent.verticalCenter
        }

        spacing: 10

        ShellIcon
        {
            anchors.verticalCenter: parent.verticalCenter

            icon: menuItem.icon
            zoom: 1.05
        }
        ShellText
        {
            anchors.verticalCenter: parent.verticalCenter

            label: menuItem.text
            color: menuItem.danger ? Theme.colorCritical : Theme.text1
        }
    }

    ShellText
    {
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        label: menuItem.trailing
        color: Theme.text3
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menuItem.clicked()
    }
}
