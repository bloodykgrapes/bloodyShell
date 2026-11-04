import QtQuick

import "../core"

Image
{
    id: shellIcon

    layer.enabled: visible && Theme.onGlass(shellIcon)
    layer.effect: ForegroundShadow {}

    property string icon: ""
    property int    size: 16

    property real zoom: 1

    visible: icon !== ""

    source: icon

    width:  Math.round(size * Config.themeScale)
    height: Math.round(size * Config.themeScale)

    sourceSize.width:  Math.round(width * zoom)
    sourceSize.height: Math.round(height * zoom)

    smooth: true
    mipmap: zoom > 1
    asynchronous: true

    fillMode: Image.PreserveAspectFit
}
