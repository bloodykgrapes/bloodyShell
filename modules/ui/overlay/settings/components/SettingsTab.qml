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

    readonly property bool hovered: enabled && (area.containsMouse || activeFocus)

    width: parent ? parent.width : 200
    height: 32
    activeFocusOnTab: enabled
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }

    Accessible.role: Accessible.PageTab
    Accessible.name: title
    Accessible.selected: selected
    Accessible.onPressAction: if (enabled) clicked()

    scale: area.pressed ? 0.97 : area.containsMouse ? 1.03 : 1
    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.radiusLarge - 2

        color: Theme.colorHover
        opacity: settingsTab.hovered && !settingsTab.selected ? 1 : 0
        Smooth on opacity { duration: 160 }
    }

    Row
    {
        x: 12
        width: parent.width - 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 11

        ShellIcon
        {
            id: glyph
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
            width: Math.max(0, parent.width - glyph.width - parent.spacing)
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
