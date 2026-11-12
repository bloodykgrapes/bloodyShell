import QtQuick

Image
{
    property string icon: ""
    property int    size: 16

    property real zoom: 1

    visible: icon !== ""

    source: icon

    width: size
    height: size

    sourceSize.width:  Math.round(width * zoom)
    sourceSize.height: Math.round(height * zoom)

    smooth: true
    mipmap: zoom > 1
    asynchronous: true

    fillMode: Image.PreserveAspectFit
}
