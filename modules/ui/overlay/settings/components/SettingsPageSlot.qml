import QtQuick

import "../../../../core"

Loader
{
    id: settingsPageSlot

    property real shift: 0

    function enter(url, direction)
    {
        leaving.stop();
        z = 1;
        source = url;

        if (!Config.animationsEnabled) { opacity = 1; shift = 0; return; }

        entering.stop();
        opacity = 0;
        shift = 36 * direction;
        entering.start();
    }
    function leave(direction)
    {
        entering.stop();
        z = 0;
        if (!item) return;

        if (!Config.animationsEnabled) { source = ""; return; }

        leaveShift.to = -14 * direction;
        leaving.start();
    }

    transform: Translate { y: settingsPageSlot.shift }

    SequentialAnimation
    {
        id: entering

        PauseAnimation { duration: 70 }
        ParallelAnimation
        {
            NumberAnimation { target: settingsPageSlot; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: settingsPageSlot; property: "shift"; to: 0; duration: Theme.animationDurationOpen; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
        }
    }

    ParallelAnimation
    {
        id: leaving

        NumberAnimation { target: settingsPageSlot; property: "opacity"; to: 0; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { id: leaveShift; target: settingsPageSlot; property: "shift"; duration: 110; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate }

        onFinished: settingsPageSlot.source = ""
    }
}
