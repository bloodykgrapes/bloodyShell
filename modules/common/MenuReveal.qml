pragma ComponentBehavior: Bound

import QtQuick
import "../core"

Item
{
    id: menuReveal

    default property alias content: body.data
    property real progress: 0
    property point origin: Qt.point(0, 0)
    property color color: Theme.colorSolid
    property real radius: Theme.radiusLarge
    property real borderWidth: Theme.panelBorderWidth
    property color borderColor: Theme.colorPanelEdge
    property bool useSurfaceMaterial: true

    readonly property real amount: Math.max(0, Math.min(1, progress))
    readonly property real anchorX: Math.max(0, Math.min(1, origin.x))
    readonly property real anchorY: Math.max(0, Math.min(1, origin.y))
    readonly property real revealWidth: width * (1 - (Config.animationsFluid ? 0.35 : 0.18) * (1 - amount))
    readonly property real revealHeight: height * (1 - (Config.animationsFluid ? 0.65 : 0.40) * (1 - amount))
    readonly property alias surface: panel

    opacity: amount

    SurfaceShadow { surface: panel; cornerRadius: menuReveal.radius; frosted: panel.materialSurface.frosted }

    RoundedShellSurface
    {
        id: panel
        objectName: "menuRevealPanel"
        x: (menuReveal.width - width) * menuReveal.anchorX
        y: (menuReveal.height - height) * menuReveal.anchorY
        width: menuReveal.revealWidth
        height: menuReveal.revealHeight
        baseColor: menuReveal.color
        radius: menuReveal.radius
        border.width: menuReveal.borderWidth
        border.color: menuReveal.borderColor
        materialEnabled: menuReveal.useSurfaceMaterial && menuReveal.amount > 0.01

        Item
        {
            id: body
            // Keep the final content size while revealing it, without reflowing text.
            x: -panel.x
            y: -panel.y
            width: menuReveal.width
            height: menuReveal.height
        }
    }
}
