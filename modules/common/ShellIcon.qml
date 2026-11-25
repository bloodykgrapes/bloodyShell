import QtQuick
import QtQuick.Window

Image
{
    property string icon: ""
    property int    size: 16

    property real zoom: 1

    visible: icon !== ""

    source: icon

    width: size
    height: size

    // Keep spare resolution for parent hover transforms without reloading each frame.
    sourceSize.width: Math.ceil(width * Math.max(2, zoom) * Screen.devicePixelRatio)
    sourceSize.height: Math.ceil(height * Math.max(2, zoom) * Screen.devicePixelRatio)

    smooth: true
    mipmap: true
    asynchronous: true

    fillMode: Image.PreserveAspectFit
}
