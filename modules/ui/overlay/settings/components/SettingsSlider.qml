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

    function ratio(v) { return to > from ? Math.max(0, Math.min(1, (v - from) / (to - from))) : 0 }
    function adjust(v)
    {
        if (!enabled || to <= from) return;
        const next = Math.max(from, Math.min(to, v));
        if (next !== value) moved(next);
    }

    implicitWidth: 240
    width: implicitWidth
    height: 28
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

        anchors { left: parent.left; right: percent.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        height: 6

        Rectangle
        {
            anchors.fill: parent
            radius: height / 2
            color: Theme.colorLine
        }

        Rectangle
        {
            width: parent.width * settingsSlider.ratio(settingsSlider.shown)
            height: parent.height
            radius: height / 2
            color: Theme.colorAccent

            Glide on width { enabled: Config.animationsEnabled && !area.pressed }
        }
    }

    ShellText
    {
        id: percent
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: Math.round(36 * Config.themeScale)
        horizontalAlignment: Text.AlignRight
        label: Math.round(settingsSlider.ratio(settingsSlider.shown) * 100) + "%"
        font.family: Theme.fontMono
    }

    MouseArea
    {
        id: area

        property real dragValue: 0

        function update(x)
        {
            if (track.width <= 0 || settingsSlider.to <= settingsSlider.from) return;
            dragValue = settingsSlider.from + Math.max(0, Math.min(1, x / track.width)) * (settingsSlider.to - settingsSlider.from);
            settingsSlider.moved(dragValue);
        }

        x: track.x
        width: track.width
        height: parent.height
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
