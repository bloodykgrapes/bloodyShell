import QtQuick
import QtQuick.Effects

import "../../../core"
import "../../../services"

Item
{
    id: lockBackdrop
    objectName: "lockBackdrop"

    property real leave: 0
    property real promptReveal: 0
    readonly property real blurAmount: 0.8 * promptReveal
    clip: true

    Image
    {
        anchors.fill: parent
        anchors.margins: -24 * lockBackdrop.promptReveal
        objectName: "lockWallpaper"
        source: ServiceAppearance.fileUrl(ServiceAppearance.wallpaperImage)
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.round(lockBackdrop.width), Math.round(lockBackdrop.height))
        asynchronous: false
        cache: true
        scale: 1 + 0.035 * lockBackdrop.promptReveal + (Config.animationsFluid ? 0.04 * lockBackdrop.leave : 0)
        layer.enabled: lockBackdrop.promptReveal > 0 && GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect
        {
            blurEnabled: true
            blurMax: 32
            blur: lockBackdrop.blurAmount
            autoPaddingEnabled: false
        }
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 + 0.06 * lockBackdrop.promptReveal + 0.35 * lockBackdrop.leave }
}
