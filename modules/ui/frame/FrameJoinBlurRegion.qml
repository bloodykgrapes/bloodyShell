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

    function position(along, radius)
    {
        const across = far ? edge.face - radius : edge.face;
        return horizontal ? Qt.point(along, across) : Qt.point(across, along);
    }

    FrameJoinCornerRegion
    {
        cornerSize: region.edge.startRadius
        origin: region.position(region.edge.start - cornerSize, cornerSize)
        roundRight: region.horizontal || region.far
        roundBottom: !region.horizontal || region.far
    }
    FrameJoinCornerRegion
    {
        cornerSize: region.edge.endRadius
        origin: region.position(region.edge.end, cornerSize)
        roundRight: !region.horizontal && region.far
        roundBottom: region.horizontal && region.far
    }
}
