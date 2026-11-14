import QtQuick
import "." as Common

import "../animations"
import "../core"

Common.InteractiveControl
{
    id: button

    property alias color: surface.color
    property alias radius: surface.radius
    property alias border: surface.border
    background: Rectangle { id: surface }

    property string text: ""
    property string icon: ""
    property int iconSize: 12
    property bool danger: false
    property bool iconOnly: false
    property bool autoRepeat: false
    property real hoverScale: iconOnly ? 1.08 : 1.03
    property real pressScale: iconOnly ? 0.92 : 0.96
    property real disabledOpacity: 0.4
    property real maximumWidth: 0
    property bool repeated: false
    readonly property bool highlighted: enabled && (hovered || visualFocus)
    readonly property bool pressed: enabled && area.pressed
    signal clicked()

    implicitWidth: iconOnly ? 28 : content.implicitWidth + 30
    implicitHeight: iconOnly ? 28 : 32
    width: implicitWidth
    height: implicitHeight
    radius: Theme.radiusMedium
    border.width: 0
    opacity: enabled ? 1 : disabledOpacity
    activeFocusOnTab: enabled
    color: danger ? Qt.rgba(Theme.colorCritical.r, Theme.colorCritical.g, Theme.colorCritical.b, 0.12) : Theme.colorField
    Tint on color {}

    scale: pressed ? pressScale : highlighted ? hoverScale : 1
    Spring on scale {}

    Keys.onSpacePressed: event => { if (!event.isAutoRepeat || autoRepeat) clicked(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat || autoRepeat) clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat || autoRepeat) clicked(); event.accepted = true }

    Rectangle
    {
        anchors.fill: parent
        radius: button.radius
        color: button.danger ? Qt.rgba(Theme.colorCritical.r, Theme.colorCritical.g, Theme.colorCritical.b, 0.12) : Theme.colorHoverStrong
        opacity: button.highlighted && !button.pressed ? 1 : 0
        Smooth on opacity {}
        Tint on color {}
    }
    Rectangle
    {
        anchors.fill: parent
        radius: button.radius
        color: button.danger ? Qt.rgba(Theme.colorCritical.r, Theme.colorCritical.g, Theme.colorCritical.b, 0.22) : Theme.colorPressed
        opacity: button.pressed ? 1 : 0
        Smooth on opacity { duration: 80 }
        Tint on color {}
    }

    Row
    {
        id: content
        anchors.centerIn: parent
        spacing: 6

        ShellIcon
        {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            icon: button.icon
            size: button.iconSize
            zoom: button.iconOnly ? 1.1 : 1
        }
        ShellText
        {
            anchors.verticalCenter: parent.verticalCenter
            width: button.maximumWidth > 0 ? Math.min(implicitWidth, Math.max(0, button.maximumWidth - 30 - (glyph.visible ? glyph.width + content.spacing : 0))) : implicitWidth
            label: button.iconOnly ? "" : button.text
            color: button.danger ? Theme.colorCritical : Theme.text1
            Tint on color {}
        }
    }

    Timer
    {
        id: repeatTimer
        interval: 380
        repeat: true
        running: button.pressed && button.autoRepeat
        onTriggered:
        {
            button.repeated = true;
            interval = 70;
            button.clicked();
        }
    }
    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: button.focusFor(Qt.MouseFocusReason)
        onPressedChanged: if (pressed) { button.repeated = false; repeatTimer.interval = 380 }
        onClicked: if (!button.repeated) button.clicked()
    }

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled) clicked()
}
