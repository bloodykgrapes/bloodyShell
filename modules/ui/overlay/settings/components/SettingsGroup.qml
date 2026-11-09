import QtQuick

import "../../../../common"
import "../../../../core"

Column
{
    id: settingsGroup

    property string title: ""
    property string subtitle: ""

    default property alias content: rows.data

    width: parent ? parent.width : 400
    spacing: 10

    property real rise: 0
    transform: Translate { y: settingsGroup.rise }

    Component.onCompleted: if (Config.animationsFluid) opacity = 0

    function enter(order)
    {
        entrance.delay = Math.min(6, order) * 45;
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

    Column
    {
        x: 4
        width: parent.width - 8
        spacing: 3

        ShellText
        {
            label: settingsGroup.title
            size: 13
            color: Theme.text1
            font.weight: Font.DemiBold
        }
        ShellText
        {
            width: parent.width
            label: settingsGroup.subtitle
            size: 11
            color: Theme.text3
            wrapMode: Text.Wrap
        }
    }

    Column { id: rows; width: parent.width; spacing: 1 }
}
