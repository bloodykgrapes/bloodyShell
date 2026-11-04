import QtQuick
import QtQuick.Effects

RectangularShadow
{
    property Item target: parent

    anchors.fill: target
    z: target === parent ? -1 : 0
    radius: target ? target.radius : 0
    scale: target && target !== parent ? target.scale : 1
    blur: 18
    spread: 1
    offset.y: 3
    color: Qt.rgba(0, 0, 0, 0.5)
}
