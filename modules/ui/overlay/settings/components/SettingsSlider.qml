import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Item
{
    id: settingsSlider

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: (to - from) / 20

    signal moved(real value)

    readonly property real shown: area.pressed ? area.dragValue : value
    property real fraction: ratio(shown)
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
    height: Theme.settingsControlHeight
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
    Accessible.description: Math.round(ratio(shown) * 100) + "%"
    Accessible.onIncreaseAction: adjust(value + step)
    Accessible.onDecreaseAction: adjust(value - step)

    Item
    {
        id: track

        readonly property real inset: Math.min(9, width / 2)
        readonly property real travel: Math.max(0, width - inset * 2)
        readonly property real position: inset + travel * settingsSlider.fraction

        anchors { left: parent.left; right: readout.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        height: 8

        Rectangle
        {
            anchors.fill: parent
            radius: height / 2
            color: Theme.colorField
        }

        Rectangle
        {
            width: track.position
            height: parent.height
            radius: height / 2
            color: Theme.colorAccent
        }

        Rectangle
        {
            x: track.position - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: width
            radius: width / 2
            color: Theme.colorAccent
            opacity: area.pressed ? 0.18 : area.containsMouse || settingsSlider.activeFocus ? 0.1 : 0
            scale: area.pressed || area.containsMouse || settingsSlider.activeFocus ? 1 : 0.7

            Smooth on opacity {}
            Smooth on scale {}
        }

        Rectangle
        {
            x: track.position - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: width
            radius: width / 2
            color: Theme.colorAccent
            scale: area.pressed ? 0.9 : area.containsMouse ? 1.1 : 1

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
        color: Theme.colorField

        ShellText
        {
            anchors.centerIn: parent
            label: Math.round(settingsSlider.ratio(settingsSlider.shown) * 100) + "%"
            color: area.pressed || settingsSlider.activeFocus ? Theme.text1 : Theme.text2
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

        onPressed: mouse => { settingsSlider.forceActiveFocus(Qt.MouseFocusReason); update(mouse.x) }
        onPositionChanged: mouse => { if (pressed) update(mouse.x) }
        onWheel: wheel =>
        {
            const delta = wheel.pixelDelta.y || wheel.angleDelta.y;
            if (delta === 0) { wheel.accepted = false; return; }
            settingsSlider.adjust(settingsSlider.value + (delta > 0 ? settingsSlider.step : -settingsSlider.step));
        }
    }
}
