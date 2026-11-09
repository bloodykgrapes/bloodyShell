pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

import "../core"
import "../services"

Item
{
    id: equalizer

    property int style: Config.equalizerStyle
    property var samples: null
    property int bars: 0
    property real spacing: 2
    property real barWidth: 2
    property real minimumHeight: 2
    property real radius: 0
    property color topColor: Theme.accentShell ? Theme.accentAlpha(0.05) : Theme.inkAlpha(0.03)
    property color bottomColor: Theme.accentShell ? Theme.accentAlpha(0.3) : Theme.inkAlpha(0.14)
    property bool active: true
    property bool animated: Config.animationsEnabled

    implicitWidth: 110
    implicitHeight: 32
    clip: true

    readonly property int barCount: width <= 0 ? 0 : bars > 0 ? bars
        : Math.max(1, Math.floor((width + Math.max(0, spacing)) / Math.max(1, barWidth + Math.max(0, spacing))))
    readonly property real actualSpacing: barCount > 1 ? Math.min(Math.max(0, spacing), width / (barCount - 1)) : 0
    readonly property real actualBarWidth: barCount > 0 ? Math.max(0, (width - actualSpacing * (barCount - 1)) / barCount) : 0
    readonly property bool running: active && activity.active && animated && !ServiceLock.locked && barCount > 0

    readonly property bool streaming: running && samples === null
    readonly property int sampleCount: style === Enums.EqualizerWaves ? Math.max(2, Math.min(32, barCount)) : barCount

    onStreamingChanged: ServiceMedia.setVisualizerActive(equalizer, streaming)
    Component.onCompleted: ServiceMedia.setVisualizerActive(equalizer, streaming)
    Component.onDestruction: ServiceMedia.setVisualizerActive(equalizer, false)

    RenderActivity
    {
        id: activity
        target: equalizer
    }

    readonly property var levels:
    {
        if (!running && samples === null) return [];
        const source = samples !== null ? samples : ServiceMedia.levels;
        const result = [];
        const step = sampleCount > 1 ? Math.max(0, source.length - 1) / (sampleCount - 1) : 0;
        for (let i = 0; i < sampleCount; i++)
        {
            const sample = i * step, lower = Math.floor(sample), blend = sample - lower;
            result.push((source[lower] || 0) * (1 - blend) + (source[lower + 1] || 0) * blend);
        }
        return result;
    }

    Gradient
    {
        id: colors
        GradientStop { position: 0; color: equalizer.topColor }
        GradientStop { position: 1; color: equalizer.bottomColor }
    }

    Loader
    {
        anchors.fill: parent
        sourceComponent: equalizer.style === Enums.EqualizerWaves ? waves : barsView
    }

    Component
    {
        id: barsView

        Item
        {
            Repeater
            {
                model: equalizer.barCount
                Rectangle
                {
                    required property int index
                    objectName: "equalizerBar"
                    x: index * (equalizer.actualBarWidth + equalizer.actualSpacing)
                    anchors.bottom: parent.bottom
                    width: equalizer.actualBarWidth
                    height: Math.min(equalizer.height, Math.max(0, equalizer.minimumHeight,
                        equalizer.running || equalizer.samples !== null ? equalizer.height * (equalizer.levels[index] || 0) : 0))
                    radius: equalizer.radius
                    gradient: colors

                    Behavior on height
                    {
                        enabled: equalizer.running && equalizer.samples === null
                        NumberAnimation { duration: ServiceMedia.cavaMissing ? 160 : 50; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }

    Component
    {
        id: waves

        Shape
        {
            id: wave
            objectName: "equalizerWaves"
            preferredRendererType: Shape.CurveRenderer

            property var target: []
            property var values: []
            property bool settling: false
            readonly property string path: curve(values)

            function update()
            {
                const source = equalizer.levels.length > 0 ? equalizer.levels : [0, 0];
                target = source.map((value, index) =>
                {
                    let sum = 0;
                    for (let offset = -2; offset <= 2; offset++)
                        sum += source[Math.max(0, Math.min(source.length - 1, index + offset))] * (3 - Math.abs(offset));
                    return sum / 9;
                });
                if (values.length !== target.length || !equalizer.running)
                {
                    if (values.length !== target.length || equalizer.samples === null) values = target;
                    settling = false;
                }
                else settling = true;
            }

            FrameAnimation
            {
                running: wave.settling && equalizer.running
                onTriggered:
                {
                    const delta = Math.min(frameTime, 0.05);
                    let moving = false;
                    const next = wave.target.map((target, index) =>
                    {
                        const current = wave.values[index] ?? target;
                        const distance = target - current;
                        if (Math.abs(distance) < 0.0005) return target;
                        moving = true;
                        const weight = 1 - Math.exp(-delta / (distance > 0 ? 0.10 : 0.22));
                        return current + distance * weight;
                    });
                    wave.values = next;
                    wave.settling = moving;
                }
            }

            function curve(levels)
            {
                if (width <= 0 || height <= 0 || levels.length < 2) return "";
                const step = width / (levels.length - 1);
                const y = value => height - Math.min(height, Math.max(0, equalizer.minimumHeight, height * value));
                let result = "M 0 " + height + " L 0 " + y(levels[0]);
                for (let i = 1; i < levels.length; i++)
                {
                    const start = y(levels[i - 1]), end = y(levels[i]);
                    const low = Math.min(start, end), high = Math.max(start, end);
                    const first = Math.max(low, Math.min(high, start + (end - y(levels[Math.max(0, i - 2)])) / 6));
                    const second = Math.max(low, Math.min(high, end - (y(levels[Math.min(levels.length - 1, i + 1)]) - start) / 6));
                    result += " C " + (i - 2 / 3) * step + " " + first + " " + (i - 1 / 3) * step + " " + second + " " + i * step + " " + end;
                }
                return result + " L " + width + " " + height + " Z";
            }

            Component.onCompleted: update()
            Connections
            {
                target: equalizer
                function onLevelsChanged() { wave.update() }
                function onRunningChanged() { wave.update() }
            }
            ShapePath
            {
                strokeColor: "transparent"
                strokeWidth: 0
                fillGradient: LinearGradient
                {
                    x1: 0; y1: 0; x2: 0; y2: wave.height
                    GradientStop { position: 0; color: equalizer.topColor }
                    GradientStop { position: 1; color: equalizer.bottomColor }
                }
                PathSvg { path: wave.path }
            }
        }
    }
}
