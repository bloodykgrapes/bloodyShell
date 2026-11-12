import QtQuick
import QtQuick.Effects

import "../../animations"
import "../../core"
import "../../services"

Item
{
    id: wallpaper

    required property string outputName
    readonly property bool blurRequested: Config.desktopBlur === Enums.BlurAlways
        || (Config.desktopBlur === Enums.BlurWindowPresented && ServiceCompositor.workspaceHasWindowsOnOutput(outputName))
    readonly property bool videoActive: ServiceAppearance.videoPath !== "" && ServiceAppearance.videoComponent !== null
        && ServiceAppearance.videoComponent.status === Component.Ready
    property real blurProgress: blurRequested && !changing && (videoActive || image.status === Image.Ready) ? 1 : 0
    property string imagePath: ""
    property bool changing: ServiceAppearance.wallpaperBusy

    clip: true
    Smooth on blurProgress { duration: 300 }

    function updateImage() { imagePath = Config.wallpaperCurrent; }
    Component.onCompleted: updateImage()

    Connections
    {
        target: Config
        function onWallpaperCurrentChanged() { if (!wallpaper.changing) wallpaper.updateImage(); }
    }
    Connections
    {
        target: ServiceAppearance
        function onWallpaperBusyChanged()
        {
            if (ServiceAppearance.wallpaperBusy) { settle.stop(); wallpaper.changing = true; }
            else settle.restart();
        }
    }
    Timer
    {
        id: settle
        // awww finishes its transition after the apply command returns.
        interval: Config.animationsEnabled && Config.wallpaperTransition !== "none" ? 1400 : 0
        onTriggered: { wallpaper.updateImage(); wallpaper.changing = false; }
    }

    Item
    {
        anchors.fill: parent
        // Keep the blur's transparent sampling edges outside the display.
        anchors.margins: -32 * wallpaper.blurProgress
        opacity: wallpaper.videoActive ? 1 : wallpaper.blurProgress
        layer.enabled: wallpaper.blurProgress > 0
        layer.effect: MultiEffect
        {
            blurEnabled: true
            blurMax: 32
            blur: wallpaper.blurProgress
            autoPaddingEnabled: false
        }

        Image
        {
            id: image
            objectName: "wallpaperBlurImage"
            anchors.fill: parent
            visible: !wallpaper.videoActive
            source: !wallpaper.videoActive && (wallpaper.blurRequested || wallpaper.blurProgress > 0)
                && wallpaper.imagePath !== "" && !ServiceAppearance.isVideo(wallpaper.imagePath)
                ? ServiceAppearance.fileUrl(wallpaper.imagePath) : ""
            sourceSize: Qt.size(Math.ceil(wallpaper.width + 64), Math.ceil(wallpaper.height + 64))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        Loader
        {
            anchors.fill: parent
            active: wallpaper.videoActive
            sourceComponent: ServiceAppearance.videoComponent
        }
    }
}
