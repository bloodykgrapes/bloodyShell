import QtQuick

import "../../../../core"

Column
{
    id: settingsGroup

    property string title: ""

    default property alias content: rows.data

    width: parent ? parent.width : 400
    spacing: 12

    property real rise: 0
    transform: Translate { y: settingsGroup.rise }

    Component.onCompleted: if (Config.animationsFluid) enter(0)

    Connections
    {
        target: Config
        function onAnimationsEnabledChanged()
        {
            if (Config.animationsEnabled) return;
            entrance.stop();
            settingsGroup.opacity = 1;
            settingsGroup.rise = 0;
        }
    }

    function enter(order)
    {
        entrance.stop();
        if (!Config.animationsFluid) { opacity = 1; rise = 0; return; }
        entrance.delay = Math.max(0, Math.min(6, order)) * 45;
        entrance.start();
    }

    SequentialAnimation
    {
        id: entrance

        property int delay: 0

        PropertyAction { target: settingsGroup; property: "opacity"; value: 0 }
        PropertyAction { target: settingsGroup; property: "rise"; value: 18 }
        PauseAnimation { duration: entrance.delay }
        ParallelAnimation
        {
            NumberAnimation { target: settingsGroup; property: "opacity"; to: 1; duration: 340; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
            NumberAnimation { target: settingsGroup; property: "rise"; to: 0; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
        }
    }

    SettingsSectionHeading
    {
        width: parent.width
        title: settingsGroup.title
    }

    Column { id: rows; width: parent.width; spacing: 1 }
}
