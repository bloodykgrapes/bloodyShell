import QtQuick

Item
{
    id: surface

    default property alias content: body.data
    property alias baseColor: fill.baseColor
    property alias materialEnabled: fill.materialEnabled
    property alias transitionMaterial: fill.transitionMaterial
    property alias border: outline.border
    property alias radius: fill.radius
    property Item cutout: null
    readonly property alias materialSurface: fill
    readonly property alias contentItem: body
    readonly property alias surfaceLayer: viewport

    ShellSurface
    {
        id: fill
        anchors.fill: parent
        visible: surface.cutout === null
    }

    Loader
    {
        anchors.fill: parent
        active: surface.cutout !== null
        sourceComponent: SurfaceCutout
        {
            color: surface.baseColor
            radius: surface.radius
            cutout: surface.cutout
        }
    }

    Item
    {
        id: viewport

        // A rectangular clip inside the corner arcs needs no offscreen mask.
        readonly property real inset: Math.min(Math.ceil(surface.radius * (1 - Math.SQRT1_2)),
            surface.width / 2, surface.height / 2)
        x: inset
        y: inset
        width: surface.width - 2 * inset
        height: surface.height - 2 * inset
        clip: true

        Item
        {
            id: body
            x: -viewport.x
            y: -viewport.y
            width: surface.width
            height: surface.height
            z: 1
        }
    }

    Rectangle
    {
        id: outline
        anchors.fill: parent
        radius: surface.radius
        color: "transparent"
        visible: border.width > 0 && border.color.a > 0
    }
}
