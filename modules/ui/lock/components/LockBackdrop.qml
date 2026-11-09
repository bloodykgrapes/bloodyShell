import QtQuick

import "../../../core"

Item
{
    id: lockBackdrop

    property real appear: 1
    property real leave: 0

    Image
    {
        anchors.fill: parent
        source: Config.wallpaperCurrent !== "" ? "file://" + String(Config.wallpaperCurrent).replace(/^file:\/\//, "") : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.round(lockBackdrop.width), Math.round(lockBackdrop.height))
        asynchronous: true
        opacity: lockBackdrop.appear
        scale: 1 + 0.04 * lockBackdrop.leave
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 + 0.35 * lockBackdrop.leave }
}
