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
    property int textSize: Theme.controlTextSize
    property string icon: ""
    property int iconSize: compact ? 13 : 14
    property string trailingIcon: ""
    property bool danger: false
    property bool primary: false
    property bool iconOnly: compact || (text === "" && icon !== "")
    property bool compact: false
    property color hoverColor: danger ? Theme.criticalAlpha(compact ? 0.22 : 0.12) : Theme.colorHoverStrong
    property color textColor: danger ? Theme.colorCritical : primary ? Theme.accentForeground : Theme.text1
    property Component iconContent: null
    property bool autoRepeat: false
    property real hoverScale: iconOnly ? 1.08 : 1.03
    property real pressScale: iconOnly ? 0.92 : 0.96
    property real disabledOpacity: 0.4
    property real maximumWidth: 0
    property bool repeated: false
    readonly property bool highlighted: enabled && (hovered || visualFocus)
    readonly property bool pressed: enabled && area.pressed
    readonly property bool hasLeadingIcon: iconContent !== null || icon !== ""
    readonly property bool hasTrailingIcon: !iconOnly && trailingIcon !== ""
    readonly property int labelInset: hasTrailingIcon ? 12 : 15
    readonly property real labelOverhead: labelInset * 2
        + (hasLeadingIcon ? iconSize + (text !== "" ? content.spacing : 0) : 0)
        + (hasTrailingIcon ? trailingGlyph.width + 8 : 0)
    readonly property real preferredLabelWidth: maximumWidth > 0
        ? Math.min(label.implicitWidth, Math.max(0, maximumWidth - labelOverhead))
        : label.implicitWidth
    signal clicked()

    implicitWidth: iconOnly ? implicitHeight : preferredLabelWidth + labelOverhead
    implicitHeight: compact ? 24 : Theme.controlHeight
    width: implicitWidth
    height: implicitHeight
    radius: compact ? Theme.radiusSmall : Theme.radiusMedium
    border.width: 0
    border.color: visualFocus ? Theme.colorFocus : "transparent"
    opacity: enabled ? 1 : disabledOpacity
    activeFocusOnTab: enabled
    color: compact ? "transparent" : danger ? Theme.criticalAlpha(0.12) : primary ? Theme.colorAccent : Theme.colorField
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
        color: button.hoverColor
        opacity: button.highlighted && !button.pressed ? 1 : 0
        Smooth on opacity {}
        Tint on color {}
    }
    Rectangle
    {
        anchors.fill: parent
        radius: button.radius
        color: button.danger ? Theme.criticalAlpha(0.22) : Theme.colorPressed
        opacity: button.pressed ? 1 : 0
        Smooth on opacity { duration: 80 }
        Tint on color {}
    }

    Row
    {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: button.hasTrailingIcon ? undefined : parent.horizontalCenter
        anchors.left: button.hasTrailingIcon ? parent.left : undefined
        anchors.leftMargin: button.labelInset
        spacing: 6

        Item
        {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            visible: button.hasLeadingIcon
            width: button.iconSize
            height: width

            ShellIcon
            {
                visible: button.iconContent === null && icon !== ""
                icon: button.icon
                size: button.iconSize
                zoom: button.iconOnly ? 1.1 : 1
            }
            Loader { anchors.fill: parent; sourceComponent: button.iconContent }
        }
        ShellText
        {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(button.preferredLabelWidth, Math.max(0, button.width - button.labelOverhead))
            label: button.iconOnly ? "" : button.text
            size: button.textSize
            color: button.textColor
            font.weight: Font.Medium
            Tint on color {}
        }
    }

    ShellIcon
    {
        id: trailingGlyph
        anchors { right: parent.right; rightMargin: button.labelInset; verticalCenter: parent.verticalCenter }
        icon: button.trailingIcon
        visible: button.hasTrailingIcon
        size: 12
        opacity: button.highlighted ? 1 : 0.7
        Smooth on opacity {}
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
