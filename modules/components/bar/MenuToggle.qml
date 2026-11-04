import QtQuick

import ".."
import "../../core"

Item
{
    id: menuToggle

    property string icon: ""
    property string text: ""
    property bool   checked: false

    signal toggle(bool value)

    width: parent ? parent.width : 200

    scale: area.pressed ? 0.98 : area.containsMouse ? 1.025 : 1
    Spring on scale {}
    height: 34

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
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 10

        ShellIcon
        {
            icon: menuToggle.icon
            size: 18
            zoom: 1.05
        }

        ShellText
        {
            anchors.verticalCenter: parent.verticalCenter
            label: menuToggle.text
            size: 13
            color: Theme.text1
        }
    }

    Rectangle
    {
        id: track
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        width: 34; height: 18; radius: 9

        color: menuToggle.checked ? Theme.colorAccent : Theme.colorLine

        Tint on color {}

        Rectangle
        {
            width: 14; height: 14; radius: 7
            y: 2
            x: menuToggle.checked ? parent.width - width - 2 : 2
            color: menuToggle.checked ? Theme.colorSolid : Theme.text3

            Glide on x {}
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: menuToggle.toggle(!menuToggle.checked)
    }
}
