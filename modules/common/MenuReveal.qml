pragma ComponentBehavior: Bound

import QtQuick
import "../animations/OverlayMotion.js" as Motion
import "../core"

Item
{
    id: menuReveal

    default property alias content: body.data
    property real progress: 0
    property point origin: Qt.point(0, 0)
    property color color: Theme.colorSolid
    property real radius: Theme.menuRadius
    property real borderWidth: Theme.panelBorderWidth
    property color borderColor: Theme.colorPanelEdge
    property bool useSurfaceMaterial: true

    readonly property real amount: Math.max(0, Math.min(1, progress))
    readonly property real anchorX: Math.max(0, Math.min(1, origin.x))
    readonly property real anchorY: Math.max(0, Math.min(1, origin.y))
    readonly property real revealWidth: width * amount
    readonly property real revealHeight: height * amount
    readonly property alias surface: panel

    SurfaceShadow
    {
        surface: panel
        cornerRadius: panel.radius
        frosted: panel.materialSurface.frosted
        cached: menuReveal.amount === 1
        opacity: menuReveal.amount
    }

    RoundedShellSurface
    {
        id: panel
        objectName: "menuRevealPanel"
        x: (menuReveal.width - width) * menuReveal.anchorX
        y: (menuReveal.height - height) * menuReveal.anchorY
        width: menuReveal.revealWidth
        height: menuReveal.revealHeight
        visible: width > 1 && height > 1
        baseColor: menuReveal.color
        radius: Math.min(menuReveal.radius, width / 2, height / 2)
        border.width: Math.min(menuReveal.borderWidth, width / 2, height / 2)
        border.color: menuReveal.borderColor
        materialEnabled: menuReveal.useSurfaceMaterial
        transitionMaterial: true

        Item
        {
            id: body
            // Keep the final content size while revealing it, without reflowing text.
            x: -panel.x
            y: -panel.y
            width: menuReveal.width
            height: menuReveal.height
            opacity: Motion.phase(menuReveal.amount, 0.12, 0.68)
        }
    }
}
