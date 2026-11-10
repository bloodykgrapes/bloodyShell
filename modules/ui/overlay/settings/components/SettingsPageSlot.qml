import QtQuick

import "../../../../core"

Loader
{
    id: settingsPageSlot

    property real shift: 0
    property bool presented: false
    enabled: presented

    function enter(url, direction)
    {
        leaving.stop();
        entering.stop();
        presented = true;
        z = 1;
        source = url;

        if (!Config.animationsEnabled || direction === 0) { opacity = 1; shift = 0; return; }

        opacity = 0;
        shift = 36 * direction;
        entering.start();
    }
    function leave(direction)
    {
        entering.stop();
        presented = false;
        z = 0;
        if (!item) return;

        if (!Config.animationsEnabled) { source = ""; return; }

        leaveShift.to = -14 * direction;
        leaving.start();
    }

    transform: Translate { y: settingsPageSlot.shift }

    Connections
    {
        target: Config
        function onAnimationsEnabledChanged()
        {
            if (Config.animationsEnabled) return;
            entering.stop();
            leaving.stop();
            settingsPageSlot.shift = 0;
            settingsPageSlot.opacity = settingsPageSlot.presented ? 1 : 0;
            if (!settingsPageSlot.presented) settingsPageSlot.source = "";
        }
    }

    ParallelAnimation
    {
        id: entering

        NumberAnimation { target: settingsPageSlot; property: "opacity"; to: 1; duration: Config.animationsFluid ? 220 : 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: settingsPageSlot; property: "shift"; to: 0; duration: Theme.animationDurationOpen; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
    }

    ParallelAnimation
    {
        id: leaving

        NumberAnimation { target: settingsPageSlot; property: "opacity"; to: 0; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { id: leaveShift; target: settingsPageSlot; property: "shift"; duration: 110; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate }

        onFinished: settingsPageSlot.source = ""
    }
}
