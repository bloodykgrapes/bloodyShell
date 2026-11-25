import QtQuick
import Quickshell.Widgets

ClippingRectangle
{
    id: surface

    property alias baseColor: fill.baseColor
    property alias materialEnabled: fill.materialEnabled
    property Item cutout: null
    readonly property alias materialSurface: fill

    color: "transparent"
    contentUnderBorder: true
    contentInsideBorder: false

    ShellSurface
    {
        id: fill
        anchors.fill: parent
        blurRadius: surface.radius
        visible: surface.cutout === null
    }

    Loader
    {
        anchors.fill: parent
        active: surface.cutout !== null
        sourceComponent: SurfaceCutout
        {
            color: surface.baseColor
            cutout: surface.cutout
        }
    }
}
