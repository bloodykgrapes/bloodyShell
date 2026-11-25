import QtQuick
import "FrameJoinGeometry.js" as JoinGeometry

FrameJoinBlurRegion
{
    id: attachment

    required property Item surface
    required property rect bar
    required property rect menu

    readonly property rect barAxes: axes(bar)
    readonly property rect menuAxes: axes(menu)
    readonly property int face: far ? barAxes.y : barAxes.y + barAxes.height
    readonly property int leading: menuAxes.x
    readonly property int trailing: menuAxes.x + menuAxes.width
    readonly property int barCapRadius: Math.ceil(Math.min(surface.bodyRadius, barAxes.width / 2, barAxes.height / 2))
    readonly property real menuCapRadius: Math.min(surface.bodyRadius, menuAxes.width / 2, menuAxes.height / 2)
    readonly property int radius: Math.floor(Math.min(surface.smoothing, menuAxes.width / 2,
        barAxes.height / 2, (far ? face - menuAxes.y : menuAxes.y + menuAxes.height - face) - menuCapRadius))
    readonly property bool attached: barAxes.width > 0 && barAxes.height > 0 && menuAxes.width > 0 && menuAxes.height > 0
        && (far ? menuAxes.y + menuAxes.height >= face + menuCapRadius : menuAxes.y <= face - menuCapRadius)
    readonly property vector4d geometry: attached && radius > 0
        ? Qt.vector4d(face, Math.max(0, Math.min(radius, leading - barAxes.x - barCapRadius)),
            Math.max(0, Math.min(radius, barAxes.x + barAxes.width - trailing - barCapRadius)), 0)
        : Qt.vector4d(0, 0, 0, 0)

    function axes(rect)
    {
        const bounds = JoinGeometry.pixelBounds(rect);
        return horizontal ? bounds : Qt.rect(bounds.y, bounds.x, bounds.height, bounds.width);
    }

    side: surface.menuSide
    edge: ({
        face, start: leading, end: trailing,
        startRadius: surface.frosted ? geometry.y : 0,
        endRadius: surface.frosted ? geometry.z : 0
    })
}
