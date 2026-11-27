import QtQuick

import "../../../animations"

Flickable
{
    id: slot

    required property bool selected
    required property real revealOpacity
    required property real maximumWidth
    required property real maximumHeight
    property alias source: loader.source
    readonly property alias item: loader.item
    property bool shown: false
    readonly property bool presented: shown || (selected && revealOpacity > 0)
    readonly property bool internalScroll: item && item.ownsScrolling === true

    width: Math.min(maximumWidth, item ? item.implicitWidth : 0)
    height: Math.min(maximumHeight, contentHeight)
    contentWidth: width
    contentHeight: loader.height
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: !internalScroll && contentHeight > height
    clip: interactive

    visible: opacity > 0
    opacity: Math.min(revealOpacity, pageOpacity)

    property real pageOpacity: selected ? 1 : 0
    Smooth on pageOpacity { duration: 140 }

    Loader
    {
        id: loader
        width: slot.width
        height: item ? item.implicitHeight : 0
        onLoaded:
        {
            slot.contentY = 0;
            if ("presented" in item) item.presented = Qt.binding(() => slot.presented);
            if ("maximumWidth" in item) item.maximumWidth = Qt.binding(() => slot.maximumWidth);
            if ("maximumHeight" in item) item.maximumHeight = Qt.binding(() => slot.maximumHeight);
        }
    }
}
