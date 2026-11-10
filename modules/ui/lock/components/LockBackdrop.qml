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
        scale: Config.animationsFluid ? 1.035 - 0.035 * lockBackdrop.appear + 0.04 * lockBackdrop.leave : 1
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 + 0.35 * lockBackdrop.leave }
}
