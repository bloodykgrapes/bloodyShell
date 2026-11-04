import QtQuick

import ".."
import "../../core"

Item
{
    id: settingsSwitch

    property bool checked: false

    signal toggled(bool value)

    width: 40
    height: 24
    opacity: enabled ? 1 : 0.4

    scale: area.pressed ? 0.97 : area.containsMouse ? 1.06 : 1
    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: height / 2
        color: settingsSwitch.checked ? Theme.colorAccent : Theme.tinted(Theme.light ? "#85858d" : "#515158", 0.10)

        Tint on color { duration: Theme.animationDurationControl }

        Rectangle
        {
            id: knob

            property real position: settingsSwitch.checked ? 1 : 0
            Glide on position {}

            property real stretch: area.pressed ? 5 : 0
            Glide on stretch {}

            y: 3
            x: 3 + position * (parent.width - 6 - width)
            width: 18 + stretch
            height: 18
            radius: 9
            color: settingsSwitch.checked ? Theme.onAccent : "#ffffff"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.14)

            Tint on color { duration: Theme.animationDurationControl }
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: settingsSwitch.toggled(!settingsSwitch.checked)
    }
}
