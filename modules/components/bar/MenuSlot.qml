import QtQuick

import ".."
import "../../core"

Loader
{
    property bool shown: false

    width: item ? item.implicitWidth : 0
    height: item ? item.implicitHeight : 0

    visible: opacity > 0
    opacity: shown ? 1 : 0
    Appear on opacity {}

    property real expansion: shown ? 1 : 0
    Spring on expansion {}

    scale: Config.animationsFluid ? 0.92 + 0.08 * expansion : 1
    transformOrigin: Config.barSide === Enums.EdgeTop ? Item.Top : Config.barSide === Enums.EdgeBottom ? Item.Bottom : Config.barSide === Enums.EdgeLeft ? Item.Left : Item.Right
}
