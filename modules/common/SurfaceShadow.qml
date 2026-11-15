import QtQuick
import QtQuick.Effects

import "../core"

RectangularShadow
{
    required property Item surface
    property real cornerRadius: Theme.radiusLarge

    anchors.fill: surface
    radius: cornerRadius + blur * 0.75
    blur: 28
    offset.y: 8
    color: Theme.colorShadow
    cached: true
    visible: surface.visible && surface.width > 0 && surface.height > 0
}
