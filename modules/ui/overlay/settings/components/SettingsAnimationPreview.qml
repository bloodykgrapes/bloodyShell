pragma ComponentBehavior: Bound

import QtQuick

import "../../../../animations/OverlayMotion.js" as Motion
import "../.." as OverlayUI
import "../../../../core"

Item
{
    id: animationPreview
    required property int mode
    required property bool playing
    required property var colors

    objectName: "animationStylePreview"
    readonly property bool minimal: mode === Enums.AnimationsDisabled
    readonly property bool fluid: mode === Enums.AnimationsFluid
    readonly property real reveal: animationPreview.playing ? progress : 1
    property real progress: 1

    OverlayUI.OverlayPanel
    {
        objectName: "animationPreviewPanel"
        anchors.centerIn: parent
        width: parent.width * 0.68
        height: parent.height * 0.62
        radius: 9
        useSurfaceMaterial: false
        reveal: animationPreview.reveal
        fluid: animationPreview.fluid
        shadow: false
        surfaceColor: {
            const ink = animationPreview.colors.ink;
            return Qt.tint(animationPreview.colors.panel, Qt.rgba(ink.r, ink.g, ink.b, 0.06));
        }
        borderWidth: 1
        borderColor: animationPreview.colors.outline
        Column
        {
            anchors.centerIn: parent
            width: parent.width * 0.72
            spacing: 5
            Row
            {
                spacing: 4
                Repeater { model: 3; Rectangle { width: 3; height: 3; radius: 1.5; color: animationPreview.colors.muted } }
            }
            Rectangle { width: parent.width * 0.85; height: 3; radius: 1.5; color: animationPreview.colors.accent }
            Rectangle { width: parent.width * 0.62; height: 3; radius: 1.5; color: animationPreview.colors.outline }
        }
    }
    SequentialAnimation
    {
        running: animationPreview.playing
        loops: Animation.Infinite
        onRunningChanged: if (!running) animationPreview.progress = 1

        PauseAnimation { duration: 520 }
        NumberAnimation
        {
            target: animationPreview; property: "progress"; from: 1; to: 0
            duration: animationPreview.minimal ? 0 : animationPreview.fluid ? Motion.fluidCloseDuration : 140
            easing.type: Easing.BezierSpline
            easing.bezierCurve: animationPreview.fluid ? Motion.fluidCloseCurve : Theme.easingAccelerate
        }
        PauseAnimation { duration: 200 }
        NumberAnimation
        {
            target: animationPreview; property: "progress"; from: 0; to: 1
            duration: animationPreview.minimal ? 0 : animationPreview.fluid ? Motion.fluidOpenDuration : 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: animationPreview.fluid ? Motion.fluidOpenCurve : [0.2, 0.0, 0.2, 1.0, 1.0, 1.0]
        }
    }
}
