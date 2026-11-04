import QtQuick

import ".."
import "../../core"

Item
{
    id: settingsSlider

    property real value: 0
    property real from: 0
    property real to: 1

    signal moved(real value)

    readonly property real shown: area.pressed ? area.dragValue : value

    function ratio(v) { return to > from ? Math.max(0, Math.min(1, (v - from) / (to - from))) : 0 }

    implicitWidth: 240
    width: implicitWidth
    height: 28
    opacity: enabled ? 1 : 0.4

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
            dragValue = settingsSlider.from + Math.max(0, Math.min(1, x / track.width)) * (settingsSlider.to - settingsSlider.from);
            settingsSlider.moved(dragValue);
        }

        x: track.x
        width: track.width
        height: parent.height
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => { if (pressed) update(mouse.x) }
        onWheel: wheel =>
        {
            const step = (settingsSlider.to - settingsSlider.from) / 20;
            settingsSlider.moved(Math.max(settingsSlider.from, Math.min(settingsSlider.to, settingsSlider.value + (wheel.angleDelta.y > 0 ? step : -step))));
        }
    }
}
