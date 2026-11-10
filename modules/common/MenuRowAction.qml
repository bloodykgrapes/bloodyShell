import QtQuick

import "../animations"
import "../core"

Rectangle
{
    id: menuRowAction

    property string icon: ""
    property string label: ""
    property bool   danger: false

    signal clicked()
    activeFocusOnTab: enabled
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }

    width: 24
    height: 24
    radius: 12

    readonly property color hot: danger ? Qt.rgba(Theme.colorCritical.r, Theme.colorCritical.g, Theme.colorCritical.b, 0.22) : Theme.colorHoverStrong
    color: area.pressed ? Theme.colorPressed : area.containsMouse || activeFocus ? hot : "transparent"
    Tint on color {}

    scale: area.pressed ? 0.9 : area.containsMouse ? 1.1 : 1
    Spring on scale {}

    ShellIcon { anchors.centerIn: parent; icon: menuRowAction.icon; size: 13; opacity: area.containsMouse ? 1 : 0.8 }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menuRowAction.clicked()
    }

    Accessible.role: Accessible.Button
    Accessible.name: menuRowAction.label
    Accessible.onPressAction: if (enabled) clicked()
}
