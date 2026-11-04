import QtQuick

import "../../components"
import "../../core"

Item
{
    id: powerTile

    property string icon: ""
    property string title: ""
    property bool   hold: false
    property bool   current: false
    property int    order: 0
    signal hovered()
    signal triggered()

    readonly property bool pressed: area.pressed

    width: 104
    height: 104

    property real progress: 0
    readonly property int holdTime: 800
    function press()
    {
        if (!enabled) return;
        if (!hold) { triggered(); return; }
        drain.stop();
        fill.duration = holdTime * (1 - progress);
        fill.restart();
    }
    function release()
    {
        if (!hold || progress >= 1) return;
        fill.stop();
        drain.restart();
    }
    NumberAnimation { id: fill; target: powerTile; property: "progress"; to: 1; easing.type: Easing.InOutQuad; onFinished: if (powerTile.progress >= 1) powerTile.triggered() }
    NumberAnimation { id: drain; target: powerTile; property: "progress"; to: 0; duration: 220; easing.type: Easing.OutCubic }

    property real rise: 0
    transform: Translate { y: powerTile.rise }
    Component.onCompleted: if (Config.animationsFluid) entrance.start()
    SequentialAnimation
    {
        id: entrance
        PropertyAction { target: powerTile; property: "opacity"; value: 0 }
        PropertyAction { target: powerTile; property: "rise"; value: 18 }
        PauseAnimation { duration: 40 + powerTile.order * 35 }
        ParallelAnimation
        {
            NumberAnimation { target: powerTile; property: "opacity"; to: 1; duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
            NumberAnimation { target: powerTile; property: "rise"; to: 0; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
        }
    }

    Column
    {
        anchors.centerIn: parent
        spacing: 10
        scale: powerTile.pressed && !powerTile.hold ? 0.92 : powerTile.current ? 1.06 : 1
        Spring on scale {}

        ShellIcon
        {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: powerTile.icon
            size: 28
            zoom: 1.1
            opacity: powerTile.current ? 1 : 0.75
            Smooth on opacity {}
        }
        Item
        {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(name.implicitWidth, hint.implicitWidth)
            height: name.implicitHeight

            ShellText
            {
                id: name
                anchors.centerIn: parent
                label: powerTile.title
                size: 12
                color: powerTile.current ? Theme.text1 : Theme.text2
                opacity: hint.opacity > 0.5 ? 0 : 1
                Smooth on opacity {}
            }

            ShellText
            {
                id: hint
                anchors.centerIn: parent
                label: Tr.tr("power.hold")
                size: 12
                color: Theme.text1
                opacity: powerTile.hold && powerTile.current ? 1 : 0
                Smooth on opacity {}
            }
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: powerTile.enabled
        onContainsMouseChanged: if (containsMouse) powerTile.hovered()
        onPressed: powerTile.press()
        onReleased: powerTile.release()
        onCanceled: powerTile.release()
        onExited: powerTile.release()
    }
}
