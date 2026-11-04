import QtQuick

import "../core"

Behavior
{
    id: ease

    property int duration: Theme.animationDurationMorph
    property bool elastic: false
    property var curve: Theme.easingEmphasized

    enabled: Config.animationsEnabled

    function current() { return targetProperty.object[targetProperty.name] }

    property real startTime: 0
    property real fromValue: 0
    property real toValue: 0
    property var  activeCurve: curve

    function slopeAt(c, t)
    {
        const x1 = c[0], y1 = c[1], x2 = c[2], y2 = c[3];
        const bx  = s => 3 * (1 - s) * (1 - s) * s * x1 + 3 * (1 - s) * s * s * x2 + s * s * s;
        const dbx = s => 3 * (1 - s) * (1 - s) * x1 + 6 * (1 - s) * s * (x2 - x1) + 3 * s * s * (1 - x2);
        const dby = s => 3 * (1 - s) * (1 - s) * y1 + 6 * (1 - s) * s * (y2 - y1) + 3 * s * s * (1 - y2);

        let s = t;
        for (let i = 0; i < 8; i++)
        {
            const d = dbx(s);
            if (Math.abs(d) < 1e-6) break;
            s = Math.max(0, Math.min(1, s - (bx(s) - t) / d));
        }
        const dx = dbx(s);
        return dx > 1e-6 ? dby(s) / dx : 0;
    }

    onTargetValueChanged:
    {
        if (!enabled) return;
        const now = Date.now();
        const from = current();
        const distance = targetValue - from;

        if (Config.animationsFluid && motion.running && Math.abs(distance) > 0.0001)
        {
            const t = Math.max(0, Math.min(1, (now - startTime) / Math.max(1, duration)));
            const velocity = slopeAt(activeCurve, t) * (toValue - fromValue) / (duration / 1000);

            const slope = Math.max(elastic ? -2 : 0, Math.min(elastic ? 8 : 4, velocity * (duration / 1000) / distance));
            activeCurve = [0.15, 0.15 * slope, curve[2], curve[3], 1.0, 1.0];
        }
        else activeCurve = curve;

        startTime = now;
        fromValue = from;
        toValue = targetValue;
    }

    NumberAnimation
    {
        id: motion

        duration: ease.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: ease.activeCurve
    }
}
