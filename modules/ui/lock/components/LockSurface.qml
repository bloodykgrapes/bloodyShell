import QtQuick

import "../../../core"

Rectangle
{
    property bool edge: true

    color: Theme.lockSurface
    border.width: edge ? 1 : 0
    border.color: Theme.lockSurfaceEdge
}
