pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

import "../../../../core"

Item
{
    id: surfacePreview
    required property int mode
    required property var colors

    objectName: "shellSurfacePreview"
    readonly property bool backdrop: mode === Enums.SurfaceBackdrop
    readonly property bool frosted: mode === Enums.SurfaceBlur
    readonly property color tint: surfacePreview.colors.frame

    Rectangle
    {
        id: desktop
        anchors.fill: parent
        color: surfacePreview.colors.canvas

        Rectangle
        {
            x: parent.width * 0.08; y: parent.height * 0.13
            width: parent.width * 0.55; height: parent.height * 0.61
            radius: 7
            color: Qt.tint(surfacePreview.colors.panel, surfacePreview.colors.outline)
            border.color: surfacePreview.colors.outline

            Column
            {
                x: 8; y: 10; spacing: 5
                Rectangle { width: 22; height: 3; radius: 1.5; color: surfacePreview.colors.muted }
                Rectangle { width: 15; height: 3; radius: 1.5; color: surfacePreview.colors.outline }
            }
        }
    }

    ClippingRectangle
    {
        id: pane
        x: Math.round(parent.width * 0.31); y: Math.round(parent.height * 0.30)
        width: parent.width * 0.61; height: parent.height * 0.58
        radius: 9
        color: surfacePreview.frosted || surfacePreview.backdrop ? "transparent" : surfacePreview.tint
        border.color: surfacePreview.colors.outline
        contentInsideBorder: false

        Rectangle
        {
            anchors.fill: parent
            visible: surfacePreview.backdrop

            gradient: Gradient
            {
                GradientStop
                {
                    position: 0
                    color: {
                        const ink = surfacePreview.colors.ink;
                        return Qt.tint(desktop.color, Qt.rgba(ink.r, ink.g, ink.b, 0.16));
                    }
                }
                GradientStop { position: 1; color: desktop.color }
            }
        }

        Loader
        {
            anchors.fill: parent
            active: surfacePreview.frosted
            sourceComponent: Item
            {
                ShaderEffectSource
                {
                    id: sample
                    x: -pane.x; y: -pane.y
                    width: desktop.width; height: desktop.height
                    visible: false
                    sourceItem: desktop
                    textureSize: Qt.size(Math.max(1, Math.round(width)), Math.max(1, Math.round(height)))
                }
                MultiEffect
                {
                    anchors.fill: sample
                    source: sample
                    blurEnabled: true
                    blur: 1
                    blurMax: 16
                    autoPaddingEnabled: false
                }
            }
        }

        Rectangle
        {
            anchors.fill: parent
            visible: surfacePreview.frosted
            color: surfacePreview.tint
            opacity: 0.36
        }

        Rectangle
        {
            x: 10; y: 10; width: 15; height: 15; radius: 5
            color: surfacePreview.colors.accent
        }
        Column
        {
            x: 32; y: 12; spacing: 4
            Rectangle { width: 25; height: 3; radius: 1.5; color: surfacePreview.colors.ink }
            Rectangle { width: 17; height: 3; radius: 1.5; color: surfacePreview.colors.muted }
        }
        Rectangle
        {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
            height: 3
            radius: 1.5
            color: surfacePreview.colors.outline
        }
    }
}
