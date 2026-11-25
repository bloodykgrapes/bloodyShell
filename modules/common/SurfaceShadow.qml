import QtQuick
import QtQuick.Effects

import "../core"

RectangularShadow
{
    required property Item surface
    property real cornerRadius: Theme.radiusLarge
    property bool frosted: false

    anchors.fill: surface
    radius: cornerRadius + blur * 0.75
    blur: 28
    offset.y: 8
    color: {
        const shadow = Theme.colorShadow;
        return frosted ? Qt.rgba(shadow.r, shadow.g, shadow.b, shadow.a * 0.40) : shadow;
    }
    cached: true
    visible: surface.visible && surface.width > 0 && surface.height > 0
}
