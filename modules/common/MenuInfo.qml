import QtQuick

import "../animations"
import "../core"

Item
{
    id: menuInfo

    property string text: ""
    property string info: ""

    width: parent ? parent.width : 200
    height: 32

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.menuColorHover

        opacity: area.containsMouse ? 1 : 0
        Smooth on opacity { duration: 175 }

        MouseArea
        {
            id: area
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    Item
    {
        anchors
        {
            left: parent.left
            right: parent.right

            leftMargin: 10
            rightMargin: 10

            verticalCenter: parent.verticalCenter
        }

        ShellText
        {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left

            label: menuInfo.text
            color: Theme.text1
        }
        ShellText
        {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right

            label: menuInfo.info
            color: Theme.text3
        }
    }
}
