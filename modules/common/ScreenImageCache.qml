import QtQuick
import Quickshell

Variants
{
    id: screenCache
    property url source: ""
    model: Quickshell.screens

    Image
    {
        required property var modelData
        visible: false
        source: screenCache.source
        sourceSize: Qt.size(Math.round(modelData.width), Math.round(modelData.height))
        asynchronous: true
        cache: true
    }
}
