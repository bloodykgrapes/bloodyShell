import QtQuick

import "../../animations/OverlayMotion.js" as Motion
import "../../common"
import "../../core"

Item
{
    id: panel

    required property real reveal
    property bool fluid: Config.animationsFluid
    property bool decorated: true
    property bool shadow: decorated
    property bool useSurfaceMaterial: true
    property Item surfaceCutout: null
    property color surfaceColor: Theme.settingsColorBackground
    property real radius: Theme.settingsRadius
    property real borderWidth: Theme.panelBorderWidth
    property color borderColor: Theme.colorPanelEdge

    default property alias content: body.data
    readonly property alias surface: viewport
    readonly property Item blurSurface: paint.materialSurface.blurActive ? paint.materialSurface : null
    readonly property alias contentItem: body
    readonly property real extent: Motion.extent(reveal, width, height)
    readonly property bool partiallyRevealed: fluid && (viewport.width < width || viewport.height < height)

    objectName: "centeredOverlayPanel"
    opacity: Motion.panelOpacity(reveal, fluid)
    layer.enabled: decorated && opacity > 0 && opacity < 1
    layer.smooth: true

    SurfaceShadow
    {
        surface: viewport
        cornerRadius: viewport.radius
        frosted: paint.materialSurface.frosted || panel.surfaceCutout?.frosted === true
        cached: !panel.partiallyRevealed
        visible: panel.shadow && viewport.visible && viewport.width > 0 && viewport.height > 0
    }

    Item
    {
        id: viewport

        width: panel.fluid ? Math.min(panel.width, panel.extent) : panel.width
        height: panel.fluid ? Math.min(panel.height, panel.extent) : panel.height
        x: (panel.width - width) / 2
        y: (panel.height - height) / 2
        readonly property real radius: Math.min(panel.radius, width / 2, height / 2)
        clip: !panel.decorated && panel.partiallyRevealed

        RoundedShellSurface
        {
            id: paint
            anchors.fill: parent
            visible: panel.decorated
            radius: viewport.radius
            baseColor: panel.surfaceColor
            cutout: panel.surfaceCutout
            materialEnabled: panel.useSurfaceMaterial && panel.reveal > 0.01
            border.width: Math.min(panel.borderWidth, width / 2, height / 2)
            border.color: panel.borderColor
        }

        Item
        {
            id: body
            parent: panel.decorated ? paint.contentItem : viewport

            // Keep the final layout while the viewport grows around it.
            width: panel.width
            height: panel.height
            x: -viewport.x
            y: -viewport.y
            opacity: panel.fluid && panel.decorated ? Motion.contentOpacity(panel.reveal) : 1
            layer.enabled: opacity > 0 && opacity < 1
            layer.smooth: true
        }
    }
}
