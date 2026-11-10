import QtQuick

import "../core"

ListView
{
    id: menuList

    property real maxHeight: 0
    property bool opening: false

    readonly property real overhang: 8
    readonly property real rowWidth: width - leftMargin - rightMargin

    x: -overhang
    width: (parent ? parent.width : 300) + overhang * 2
    leftMargin: overhang
    rightMargin: overhang
    topMargin: 2
    bottomMargin: 2
    height: maxHeight > 0 ? Math.min(contentHeight + topMargin + bottomMargin, maxHeight) : contentHeight + topMargin + bottomMargin
    visible: count > 0
    spacing: 2

    interactive: contentHeight + topMargin + bottomMargin > height + 1
    clip: interactive
    boundsBehavior: Flickable.StopAtBounds

    currentIndex: -1
    highlightFollowsCurrentItem: false

    readonly property bool animated: Config.animationsEnabled

    add: Transition
    {
        enabled: menuList.animated
        SequentialAnimation
        {
            PropertyAction { property: "opacity"; value: 0 }
            PauseAnimation { duration: menuList.opening ? Math.max(0, Math.min(8, menuList.ViewTransition.index)) * 35 : 0 }
            ParallelAnimation
            {
                NumberAnimation { property: "opacity"; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
                NumberAnimation { property: "scale"; from: menuList.opening && Config.animationsFluid ? 0.94 : 0.97; to: 1; duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
            }
        }
    }
    remove: Transition
    {
        enabled: menuList.animated
        ParallelAnimation
        {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.animationDurationClose; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate }
            NumberAnimation { property: "scale"; to: 0.96; duration: Theme.animationDurationClose; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate }
        }
    }
    displaced: Transition
    {
        enabled: menuList.animated
        NumberAnimation { properties: "x,y"; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
        NumberAnimation { property: "opacity"; to: 1; duration: 160 }
        NumberAnimation { property: "scale"; to: 1; duration: 160 }
    }
}
