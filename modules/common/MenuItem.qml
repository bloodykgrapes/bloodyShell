import QtQuick

import "../animations"
import "../core"

Item
{
    id: menuItem

    property string icon: ""
    property string text: ""
    property string trailing: ""
    property bool   danger: false
    property int iconSize: 16
    property int textSize: 12
    property real trailingInset: trailing !== "" ? trailingLabel.width + 10 : 0
    property bool actionPressed: false
    readonly property bool hovered: hover.hovered

    signal clicked()

    width: parent ? parent.width : 200
    height: 34

    scale: area.pressed || actionPressed ? 0.98 : hovered ? 1.025 : 1

    Spring on scale {}
    HoverHandler { id: hover }

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.menuColorHover
        opacity: menuItem.hovered ? 1 : 0

        Smooth on opacity {}
    }

    Row
    {
        anchors
        {
            left: parent.left
            right: parent.right

            leftMargin: 10
            rightMargin: 10 + menuItem.trailingInset

            verticalCenter: parent.verticalCenter
        }

        spacing: 10

        ShellIcon
        {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter

            icon: menuItem.icon
            size: menuItem.iconSize
            zoom: 1.05
        }
        ShellText
        {
            anchors.verticalCenter: parent.verticalCenter

            width: Math.max(0, parent.width - (glyph.visible ? glyph.width + parent.spacing : 0))
            label: menuItem.text
            size: menuItem.textSize
            color: menuItem.danger ? Theme.colorCritical : Theme.text1
        }
    }

    ShellText
    {
        id: trailingLabel
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
