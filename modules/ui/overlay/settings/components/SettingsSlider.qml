import QtQuick
import "../../../../common" as Common

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Common.InteractiveControl
{
    id: settingsSlider


    property real value: 0
    property real from: 0
    property real to: 1
    property real step: (to - from) / 20
    property string valueText: Math.round(ratio(shown) * 100) + "%"
    property bool hue: false
    property real hueFrom: 0
    property real hueTo: 360

    signal moved(real value)

    readonly property real shown: area.pressed ? area.dragValue : value
    property real fraction: ratio(shown)
    readonly property color hueColor: Qt.hsla((((shown % 360) + 360) % 360) / 360, 0.72, 0.55, 1)
    property bool settled: false

    Component.onCompleted: Qt.callLater(() => settled = true)
    Glide on fraction
    {
        enabled: Config.animationsEnabled && settingsSlider.settled && !area.pressed
        duration: Theme.animationDurationControl
    }

    function ratio(v) { return to > from ? Math.max(0, Math.min(1, (v - from) / (to - from))) : 0 }
    function adjust(v)
    {
        if (!enabled || to <= from) return;
        const next = Math.max(from, Math.min(to, v));
        if (next !== value) moved(next);
    }

    property real preferredWidth: 240
    implicitWidth: Math.round(preferredWidth)
    width: Theme.controlWidth(settingsSlider, implicitWidth)
    height: Theme.controlHeight
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: enabled
    Keys.onRightPressed: adjust(value + step)
    Keys.onUpPressed: adjust(value + step)
    Keys.onLeftPressed: adjust(value - step)
    Keys.onDownPressed: adjust(value - step)
    Keys.onPressed: event =>
    {
        if (event.key === Qt.Key_Home) adjust(from);
        else if (event.key === Qt.Key_End) adjust(to);
        else return;
        event.accepted = true;
    }

    Accessible.role: Accessible.Slider
    Accessible.description: valueText
    Accessible.onIncreaseAction: adjust(value + step)
    Accessible.onDecreaseAction: adjust(value - step)

    Item
    {
        id: track

        readonly property real inset: Math.min(13, width / 2)
        readonly property real travel: Math.max(0, width - inset * 2)
        readonly property real position: inset + travel * settingsSlider.fraction

        anchors { left: parent.left; right: readout.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        height: 6

        Rectangle
        {
            visible: !settingsSlider.hue
            anchors.fill: parent
            radius: height / 2
            color: Theme.colorField
        }

        Rectangle
        {
            visible: !settingsSlider.hue
            width: track.position
            height: parent.height
            radius: height / 2
            color: Theme.colorAccent
        }

        Rectangle
        {
            visible: settingsSlider.hue
            anchors.fill: parent
            radius: height / 2
            gradient: Gradient
            {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#ff3b30" }
                GradientStop { position: 0.17; color: "#ffcc00" }
                GradientStop { position: 0.34; color: "#34c759" }
                GradientStop { position: 0.5; color: "#32ade6" }
                GradientStop { position: 0.67; color: "#007aff" }
                GradientStop { position: 0.84; color: "#af52de" }
                GradientStop { position: 1.0; color: "#ff3b30" }
            }
        }

        Rectangle
        {
            x: track.position - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 26
            radius: 13
            color: Theme.colorAccent
            opacity: area.pressed ? 0.18 : settingsSlider.hovered || settingsSlider.visualFocus ? 0.1 : 0
            scale: area.pressed || settingsSlider.hovered || settingsSlider.visualFocus ? 1 : 0.7

            Smooth on opacity {}
            Smooth on scale {}
        }

        Rectangle
        {
            x: thumb.x - 1
            y: thumb.y + 1
            width: thumb.width + 2
            height: thumb.height + 1
            radius: thumb.radius + 1
            color: "#24000000"
            scale: thumb.scale
        }

        Rectangle
        {
            id: thumb
            x: track.position - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 16
            radius: 8
            gradient: Gradient
            {
                GradientStop { position: 0; color: "#ffffff" }
                GradientStop { position: 1; color: "#ededf0" }
            }
            scale: area.pressed ? 1.08 : settingsSlider.hovered ? 1.04 : 1

            Smooth on scale {}
        }
    }

    Rectangle
    {
        id: readout
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 48
        height: 30
        radius: Theme.radiusMedium
        color: settingsSlider.hue ? settingsSlider.hueColor : Theme.colorField

        ShellText
        {
            anchors.centerIn: parent
            label: settingsSlider.valueText
            size: Theme.controlTextSize
            color: settingsSlider.hue
                ? (Theme.lightForeground(settingsSlider.hueColor) ? "#ffffff" : "#000000")
                : area.pressed || settingsSlider.visualFocus ? Theme.text1 : Theme.text2
            font.family: Theme.fontMono

            Tint on color {}
        }
    }

    MouseArea
    {
        id: area

        property real dragValue: 0

        function update(x)
        {
            if (track.travel <= 0 || settingsSlider.to <= settingsSlider.from) return;
            dragValue = settingsSlider.from + Math.max(0, Math.min(1, (x - track.inset) / track.travel)) * (settingsSlider.to - settingsSlider.from);
            settingsSlider.moved(dragValue);
        }

        x: track.x
        width: track.width
        height: parent.height
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        onPressed: mouse => { settingsSlider.focusFor(Qt.MouseFocusReason); update(mouse.x) }
        onPositionChanged: mouse => { if (pressed) update(mouse.x) }
        onWheel: wheel =>
        {
            const delta = wheel.pixelDelta.y || wheel.angleDelta.y;
            if (delta === 0) { wheel.accepted = false; return; }
            settingsSlider.adjust(settingsSlider.value + (delta > 0 ? settingsSlider.step : -settingsSlider.step));
        }
    }
}
