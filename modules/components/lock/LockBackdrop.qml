import QtQuick
import QtQuick.Effects

import "../../core"

Item
{
    id: lockBackdrop

    property real appear: 1
    property real leave: 0

    readonly property alias image: wallpaper

    Item
    {
        id: wallpaper
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Image
        {
            id: wallImage
            anchors.fill: parent
            source: Config.wallpaperCurrent !== "" ? "file://" + String(Config.wallpaperCurrent).replace(/^file:\/\//, "") : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Math.round(lockBackdrop.width / 2), Math.round(lockBackdrop.height / 2))
            asynchronous: true
        }
    }
    MultiEffect
    {
        anchors.fill: parent
        source: wallpaper
        visible: wallImage.status === Image.Ready
        opacity: lockBackdrop.appear
        blurEnabled: true
        blur: 0.55
        blurMax: 48
        autoPaddingEnabled: false
        scale: 1 + 0.04 * lockBackdrop.leave
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 + 0.35 * lockBackdrop.leave }
}
