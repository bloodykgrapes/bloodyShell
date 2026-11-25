import QtQuick
import QtQuick.Shapes

import "../core"

Item
{
    id: surface

    property color color: "#000000"
    property Item cutout: null
    readonly property bool hasCutout: !!cutout && cutout.visible && cutout.width > 0 && cutout.height > 0
    readonly property rect opening: hasCutout ? ShellMaterial.boundsIn(cutout, surface) : Qt.rect(0, 0, 0, 0)
    readonly property real cornerScale: hasCutout ? Math.min(opening.width / cutout.width, opening.height / cutout.height) : 0

    Rectangle { anchors.fill: parent; color: surface.color; visible: !surface.hasCutout }

    Shape
    {
        anchors.fill: parent
        visible: surface.hasCutout
        preferredRendererType: Shape.CurveRenderer

        ShapePath
        {
            strokeWidth: -1
            fillColor: surface.color
            fillRule: ShapePath.OddEvenFill

            PathRectangle { width: surface.width; height: surface.height }
            PathRectangle
            {
                x: surface.opening.x
                y: surface.opening.y
                width: surface.opening.width
                height: surface.opening.height
                radius: (surface.cutout?.maskRadius ?? 0) * surface.cornerScale
            }
        }
    }
}
