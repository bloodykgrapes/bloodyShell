import QtQuick

import "../animations"
import "../core"

Item
{
    id: toggle

    property bool checked: false
    property real inset: 3
    property real thumbStretch: 5
    property real thumbBorderWidth: 1
    property real pressScale: 0.97
    property real hoverScale: 1.06
    property real disabledOpacity: 0.4
    property color uncheckedColor: Theme.tinted(Theme.light ? "#85858d" : "#515158", 0.10)
    property color checkedThumbColor: Theme.onAccent
    property color uncheckedThumbColor: "#ffffff"
    property color thumbBorderColor: Qt.rgba(0, 0, 0, 0.14)

    readonly property bool pressed: area.pressed
    readonly property bool hovered: area.containsMouse
    signal toggled(bool value)

    implicitWidth: 40
    implicitHeight: 24
    width: implicitWidth
    height: implicitHeight
    opacity: enabled ? 1 : disabledOpacity
    activeFocusOnTab: true
    Keys.onSpacePressed: toggled(!checked)
    Keys.onReturnPressed: toggled(!checked)

    scale: area.pressed ? pressScale : area.containsMouse ? hoverScale : 1
    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: height / 2
        color: toggle.checked ? Theme.colorAccent : toggle.uncheckedColor
        Tint on color { duration: Theme.animationDurationControl }

        Rectangle
        {
            property real position: toggle.checked ? 1 : 0
            property real stretch: toggle.pressed ? toggle.thumbStretch : 0
            Glide on position {}
            Glide on stretch {}

            y: toggle.inset
            x: toggle.inset + position * (parent.width - toggle.inset * 2 - width)
            width: height + stretch
            height: Math.max(0, parent.height - toggle.inset * 2)
            radius: height / 2
            color: toggle.checked ? toggle.checkedThumbColor : toggle.uncheckedThumbColor
            border.width: toggle.thumbBorderWidth
            border.color: toggle.thumbBorderColor
            Tint on color { duration: Theme.animationDurationControl }
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled(!toggle.checked)
    }

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onToggleAction: toggled(!checked)
}
