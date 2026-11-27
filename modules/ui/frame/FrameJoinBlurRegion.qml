import QtQuick
import Quickshell

import "../../core"

Region
{
    id: region

    required property int side
    required property var edge

    readonly property bool horizontal: side === Enums.EdgeTop || side === Enums.EdgeBottom
    readonly property bool far: side === Enums.EdgeRight || side === Enums.EdgeBottom

    function position(along, depth)
    {
        const across = far ? edge.face - depth : edge.face;
        return horizontal ? Qt.point(along, across) : Qt.point(across, along);
    }

    FrameJoinCornerRegion
    {
        readonly property int depth: region.edge.startRadius
        readonly property int reach: depth > 0 ? region.edge.reach ?? depth : 0
        cornerWidth: region.horizontal ? reach : depth
        cornerHeight: region.horizontal ? depth : reach
        origin: region.position(region.edge.start - reach, depth)
        roundRight: region.horizontal || region.far
        roundBottom: !region.horizontal || region.far
    }
    FrameJoinCornerRegion
    {
        readonly property int depth: region.edge.endRadius
        readonly property int reach: depth > 0 ? region.edge.reach ?? depth : 0
        cornerWidth: region.horizontal ? reach : depth
        cornerHeight: region.horizontal ? depth : reach
        origin: region.position(region.edge.end, depth)
        roundRight: !region.horizontal && region.far
        roundBottom: region.horizontal && region.far
    }
}
