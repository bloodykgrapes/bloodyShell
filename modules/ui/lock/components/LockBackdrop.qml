import QtQuick
import QtQuick.Effects
import QtQuick.Window

import "../../../common"
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

    Item
    {
        id: picture
        anchors.fill: parent
        anchors.margins: -24 * lockBackdrop.promptReveal
        objectName: "lockWallpaperLayer"
        scale: 1 + 0.035 * lockBackdrop.promptReveal + (Config.animationsFluid ? 0.04 * lockBackdrop.leave : 0)
        layer.enabled: lockBackdrop.promptReveal > 0 && GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect
        {
            blurEnabled: true
            blurMax: 32
            blur: lockBackdrop.blurAmount
            autoPaddingEnabled: false
        }

        LockWallpaperPreview
        {
            id: preview
            objectName: "lockWallpaper"
            readonly property real cover: Math.max(picture.width / Math.max(1, implicitWidth),
                picture.height / Math.max(1, implicitHeight))
            anchors.centerIn: parent
            width: implicitWidth * cover
            height: implicitHeight * cover
            source: ServiceAppearance.fileUrl(ServiceAppearance.wallpaperImage)
            visible: detail.status !== Image.Ready
            asynchronous: false
        }

        Image
        {
            id: detail
            objectName: "lockWallpaperDetail"
            anchors.fill: parent
            source: picture.visible && picture.Window.window?.visible && lockBackdrop.width > 0 && lockBackdrop.height > 0
                && (lockBackdrop.width > preview.sourceSize.width || lockBackdrop.height > preview.sourceSize.height)
                ? preview.source : ""
            sourceSize: Qt.size(Math.round(lockBackdrop.width), Math.round(lockBackdrop.height))
            visible: status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 + 0.06 * lockBackdrop.promptReveal + 0.35 * lockBackdrop.leave }
}
