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
    readonly property real peakHeight: Math.max(0, height - 1)
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

    readonly property var sourceLevels:
    {
        const source = samples !== null ? samples : running ? ServiceMedia.levels : [];
        const peak = source.reduce((maximum, value) => Number.isFinite(value) ? Math.max(maximum, value) : maximum, 1);
        return source.map(value => Number.isFinite(value) ? Math.max(0, value) / peak : 0);
    }
    readonly property int sourceCount: sourceLevels.length
    readonly property var samplePlan:
    {
        const result = [];
        const step = sampleCount > 1 ? Math.max(0, sourceCount - 1) / (sampleCount - 1) : 0;
        for (let i = 0; i < sampleCount; i++)
        {
            const sample = i * step, lower = Math.floor(sample), blend = sample - lower;
            result.push({ lower: lower, blend: blend });
        }
        return result;
    }

    readonly property var levels:
    {
        if (!running && samples === null) return [];
        const source = sourceLevels;
        return samplePlan.map(sample => (source[sample.lower] || 0) * (1 - sample.blend)
            + (source[sample.lower + 1] || 0) * sample.blend);
    }

    function levelHeight(value)
    {
        return Math.max(Math.min(Math.max(0, minimumHeight), peakHeight), peakHeight * value);
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
                    property real level: equalizer.running || equalizer.samples !== null ? equalizer.levels[index] || 0 : 0
                    objectName: "equalizerBar"
                    x: index * (equalizer.actualBarWidth + equalizer.actualSpacing)
                    anchors.bottom: parent.bottom
                    width: equalizer.actualBarWidth
                    height: equalizer.levelHeight(level)
                    radius: equalizer.radius
                    gradient: colors

                    Behavior on level
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
            property var velocities: []
            property bool settling: false
            readonly property string path: curve(values)

            function update()
            {
                const source = equalizer.levels.length > 0 ? equalizer.levels : [0, 0];
                const weights = [1, 8, 28, 56, 70, 56, 28, 8, 1];
                target = source.map((value, index) =>
                {
                    let sum = 0;
                    for (let offset = -4; offset <= 4; offset++)
                        sum += source[Math.max(0, Math.min(source.length - 1, index + offset))] * weights[offset + 4];
                    return Math.max(0, Math.min(1, sum / 256));
                });
                if (values.length !== target.length || !equalizer.running)
                {
                    values = target;
                    velocities = target.map(() => 0);
                    settling = false;
                }
                else settling = true;
            }

            function advance(frameTime)
            {
                const delta = Math.min(frameTime, 0.05);
                let moving = false;
                const velocities = [];
                const next = wave.target.map((target, index) =>
                {
                    const current = wave.values[index] ?? target;
                    const velocity = wave.velocities[index] || 0;
                    const distance = target - current;
                    if (Math.abs(distance) < 0.0005 && Math.abs(velocity) < 0.005)
                    {
                        velocities.push(0);
                        return target;
                    }
                    moving = true;
                    // A damped response keeps velocity continuous when audio frames retarget the wave.
                    const rate = distance > 0 ? 22 : 12;
                    const decay = Math.exp(-rate * delta);
                    const impulse = velocity - rate * distance;
                    const value = target + (-distance + impulse * delta) * decay;
                    const bounded = Math.max(0, Math.min(1, value));
                    velocities.push(bounded === value ? (velocity - rate * impulse * delta) * decay : 0);
                    return bounded;
                });
                wave.velocities = velocities;
                wave.values = next;
                wave.settling = moving;
            }

            FrameAnimation
            {
                running: wave.settling && equalizer.running
                onTriggered: wave.advance(frameTime)
            }

            function curve(levels)
            {
                if (width <= 0 || height <= 0 || levels.length < 2) return "";
                const step = width / (levels.length - 1);
                const points = levels.map(value => height - equalizer.levelHeight(value));
                const slopes = points.slice(1).map((value, index) => value - points[index]);
                const tangents = points.map((value, index) =>
                {
                    if (index === 0) return slopes[0];
                    if (index === points.length - 1) return slopes[slopes.length - 1];
                    const before = slopes[index - 1], after = slopes[index];
                    return before * after <= 0 ? 0 : 2 * before * after / (before + after);
                });
                let result = "M 0 " + height + " L 0 " + points[0];
                for (let i = 1; i < levels.length; i++)
                {
                    const start = points[i - 1], end = points[i];
                    const first = start + tangents[i - 1] / 3;
                    const second = end - tangents[i] / 3;
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
