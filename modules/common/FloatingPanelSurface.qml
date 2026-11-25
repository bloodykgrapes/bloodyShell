import QtQuick

import "../core"

Item
{
    id: surface

    property real reveal: 1

    SurfaceShadow
    {
        surface: fill
        cornerRadius: fill.radius
        frosted: fill.frosted
        opacity: surface.reveal
    }

    ShellSurface
    {
        id: fill
        objectName: "floatingPanelFill"
        anchors.fill: parent
        radius: Theme.barRadius
        baseColor: Theme.frameColor
        border.width: Theme.panelBorderWidth
        border.color: Theme.colorPanelEdge
    }
}
