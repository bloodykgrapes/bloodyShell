pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Widgets

import "../../../../common"
import "../../../../core"
import "../../../frame"

ClippingRectangle
{
    id: preview
    objectName: "settingsShellPreview"

    property bool showMaterialSample: false
    required property real pageHeight

    width: parent ? parent.width : 600
    height: Math.max(0, Math.round(Math.min(268, width * 0.42, pageHeight * 0.32)))
    radius: Theme.radiusLarge
    color: Theme.colorField
    border.width: 1
    border.color: Theme.colorLine
    contentInsideBorder: false
    enabled: false

    Item
    {
        id: desktop

        readonly property bool localMaterialCanvas: true
        width: preview.width / scale
        height: preview.height / scale
        scale: Math.max(0.2, Math.min(0.88, preview.width / 1060, preview.height / 310))
        transformOrigin: Item.TopLeft

        Rectangle
        {
            id: backdrop
            anchors.fill: parent
            gradient: Gradient
            {
                GradientStop { position: 0; color: Qt.tint(Theme.colorField, Theme.accentAlpha(0.18)) }
                GradientStop { position: 1; color: Theme.colorField }
            }

            WallpaperImage
            {
                anchors.fill: parent
                wallpaper: Config.wallpaperCurrent
                sourceSize: Qt.size(1024, 512)
            }
        }

        Frame
        {
            id: frame
            objectName: "settingsPreviewFrame"
            anchors.fill: parent
            preview: true
            screen: Quickshell.screens.find(output => output.name === preview.Window.window?.screen?.name)
                ?? Quickshell.screens[0] ?? null
        }

        Loader
        {
            anchors.centerIn: parent
            active: preview.showMaterialSample
            width: Math.min(350, desktop.width * 0.62)
            height: 104

            sourceComponent: SettingsSurfacePreview { backdrop: backdrop }
        }
    }
}
