import QtQuick
import "." as Common

import "../animations"
import "../core"

Common.InteractiveControl
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

    readonly property bool pressed: enabled && area.pressed
    readonly property bool highlighted: enabled && (hovered || visualFocus)
    signal toggled(bool value)

    implicitWidth: 40
    implicitHeight: 24
    width: implicitWidth
    height: implicitHeight
    opacity: enabled ? 1 : disabledOpacity
    activeFocusOnTab: enabled
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) toggled(!checked); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) toggled(!checked); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) toggled(!checked); event.accepted = true }

    scale: pressed ? pressScale : highlighted ? hoverScale : 1
    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: height / 2
        color: toggle.checked ? Theme.colorAccent : toggle.uncheckedColor
        Tint on color { duration: Theme.animationDurationControl }

        Rectangle
        {
            property real slide: toggle.checked ? 1 : 0
            property real extension: toggle.pressed ? toggle.thumbStretch : 0
            readonly property real position: Config.animationsEnabled ? slide : toggle.checked ? 1 : 0
            readonly property real stretch: Config.animationsEnabled ? extension : toggle.pressed ? toggle.thumbStretch : 0
            Glide on slide {}
            Glide on extension {}

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
        onPressed: toggle.focusFor(Qt.MouseFocusReason)
        onClicked: toggle.toggled(!toggle.checked)
    }

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onToggleAction: if (enabled) toggled(!checked)
}
