import QtQuick

import "../core"

Item
{
    width: parent ? parent.width : 200
    height: 9

    Rectangle
    {
        anchors
        {
            left: parent.left
            right: parent.right
            leftMargin: 6; rightMargin: 6
            verticalCenter: parent.verticalCenter
        }
        height: 1
        color: Theme.colorLine
    }
}
