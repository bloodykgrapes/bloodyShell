import QtQuick

import "../../../animations"
import "../../../core"

Loader
{
    id: slot

    property int side: Config.barSide
    property bool shown: false

    onLoaded: if ("presented" in item) item.presented = Qt.binding(() => slot.shown)

    width: item ? item.implicitWidth : 0
    height: item ? item.implicitHeight : 0

    visible: opacity > 0
    opacity: shown ? 1 : 0
    Appear on opacity {}

    property real expansion: shown ? 1 : 0
    Spring on expansion {}

    scale: Config.animationsFluid ? 0.92 + 0.08 * expansion : 1
    transformOrigin: side === Enums.EdgeTop ? Item.Top : side === Enums.EdgeBottom ? Item.Bottom : side === Enums.EdgeLeft ? Item.Left : Item.Right
}
