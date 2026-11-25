import QtQuick
import Quickshell

Region
{
    id: corner

    required property point origin
    required property int cornerSize
    required property bool roundRight
    required property bool roundBottom

    x: origin.x
    y: origin.y
    width: cornerSize
    height: cornerSize

    // Keep the part of the square outside the rounded desktop opening.
    Region
    {
        intersection: Intersection.Subtract
        x: corner.x - (corner.roundRight ? corner.cornerSize : 0)
        y: corner.y - (corner.roundBottom ? corner.cornerSize : 0)
        width: corner.cornerSize * 2
        height: corner.cornerSize * 2
        topLeftRadius: !corner.roundRight && !corner.roundBottom ? corner.cornerSize : 0
        topRightRadius: corner.roundRight && !corner.roundBottom ? corner.cornerSize : 0
        bottomLeftRadius: !corner.roundRight && corner.roundBottom ? corner.cornerSize : 0
        bottomRightRadius: corner.roundRight && corner.roundBottom ? corner.cornerSize : 0
    }
}
