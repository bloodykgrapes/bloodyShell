import QtQuick
import Quickshell

import "../../core"
import "FrameJoinGeometry.js" as JoinGeometry

Region
{
    id: body

    required property Item surface
    required property rect area
    required property real join

    readonly property var shape: JoinGeometry.bodyShape(area, surface.width, surface.height, surface.inset,
        surface.bodyRadius, join, surface.frosted)
    readonly property rect bounds: shape.bounds
    readonly property vector4d corners: shape.corners
    readonly property vector4d fillets: shape.fillets

    function perimeter(side, radius)
    {
        const horizontal = side === Enums.EdgeTop || side === Enums.EdgeBottom;
        const far = side === Enums.EdgeRight || side === Enums.EdgeBottom;
        const inset = surface.inset;
        const start = horizontal ? bounds.x : bounds.y;
        const end = start + (horizontal ? bounds.width : bounds.height);
        const span = horizontal ? surface.width : surface.height;
        const depth = horizontal ? surface.height : surface.width;
        return {
            face: far ? depth - inset : inset, start, end,
            startRadius: surface.frosted && start > inset ? radius : 0,
            endRadius: surface.frosted && end < span - inset ? radius : 0
        };
    }

    x: bounds.x
    y: bounds.y
    width: surface.frosted ? bounds.width : 0
    height: surface.frosted ? bounds.height : 0
    topLeftRadius: corners.x
    topRightRadius: corners.y
    bottomLeftRadius: corners.z
    bottomRightRadius: corners.w

    FrameJoinBlurRegion { side: Enums.EdgeTop; edge: body.perimeter(side, body.fillets.x) }
    FrameJoinBlurRegion { side: Enums.EdgeBottom; edge: body.perimeter(side, body.fillets.y) }
    FrameJoinBlurRegion { side: Enums.EdgeLeft; edge: body.perimeter(side, body.fillets.z) }
    FrameJoinBlurRegion { side: Enums.EdgeRight; edge: body.perimeter(side, body.fillets.w) }
}
