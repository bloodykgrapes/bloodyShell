import QtQuick
import Quickshell

Region
{
    id: corner

    required property point origin
    required property int cornerWidth
    required property int cornerHeight
    required property bool roundRight
    required property bool roundBottom

    x: origin.x
    y: origin.y
    width: cornerWidth
    height: cornerHeight

    // Keep the quarter outside the elliptical cut, matching the shader's join.
    Region
    {
        intersection: Intersection.Subtract
        shape: RegionShape.Ellipse
        x: corner.x - (corner.roundRight ? corner.cornerWidth : 0)
        y: corner.y - (corner.roundBottom ? corner.cornerHeight : 0)
        width: corner.cornerWidth * 2
        height: corner.cornerHeight * 2
    }
}
