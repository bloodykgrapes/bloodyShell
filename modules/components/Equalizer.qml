pragma ComponentBehavior: Bound

import QtQuick

import "../core"
import "../services"

Item
{
    id: equalizer

    property int bars: 0
    property real spacing: 2
    property real barWidth: 2
    property real minimumHeight: 2
    property real radius: 0
    property color topColor: Theme.accentShell ? Theme.accentAlpha(0.05) : Theme.inkAlpha(0.03)
    property color bottomColor: Theme.accentShell ? Theme.accentAlpha(0.3) : Theme.inkAlpha(0.14)
    property bool active: true

    implicitWidth: 110
    implicitHeight: 32
    clip: true

    readonly property int barCount: width <= 0 ? 0 : bars > 0 ? bars
        : Math.max(1, Math.floor((width + Math.max(0, spacing)) / Math.max(1, barWidth + Math.max(0, spacing))))
    readonly property real actualSpacing: barCount > 1 ? Math.min(Math.max(0, spacing), width / (barCount - 1)) : 0
    readonly property real actualBarWidth: barCount > 0 ? Math.max(0, (width - actualSpacing * (barCount - 1)) / barCount) : 0
    readonly property bool running: active && activity.active && Config.animationsEnabled && barCount > 0

    onRunningChanged: ServiceMedia.setVisualizerActive(equalizer, running)
    Component.onCompleted: ServiceMedia.setVisualizerActive(equalizer, running)
    Component.onDestruction: ServiceMedia.setVisualizerActive(equalizer, false)

    RenderActivity
    {
        id: activity
        target: equalizer
    }

    Repeater
    {
        model: equalizer.barCount

        Rectangle
        {
            required property int index

            readonly property real sample: equalizer.barCount > 1
                ? index * Math.max(0, ServiceMedia.levels.length - 1) / (equalizer.barCount - 1) : 0
            readonly property int lower: Math.floor(sample)
            readonly property real level: (ServiceMedia.levels[lower] || 0) * (1 - sample + lower)
                + (ServiceMedia.levels[Math.ceil(sample)] || 0) * (sample - lower)

            x: index * (equalizer.actualBarWidth + equalizer.actualSpacing)
            anchors.bottom: parent.bottom
            width: equalizer.actualBarWidth
            height: Math.min(equalizer.height, Math.max(0, equalizer.minimumHeight,
                equalizer.running ? equalizer.height * level : 0))
            radius: equalizer.radius

            gradient: Gradient
            {
                GradientStop { position: 0; color: equalizer.topColor }
                GradientStop { position: 1; color: equalizer.bottomColor }
            }

            Behavior on height
            {
                enabled: equalizer.running
                NumberAnimation { duration: ServiceMedia.cavaMissing ? 160 : 50; easing.type: Easing.OutQuad }
            }
        }
    }
}
