import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Widgets

import "../core"

Rectangle
{
    id: surface

    property color baseColor: Theme.colorSolid
    property bool materialEnabled: true
    property real blurRadius: radius
    readonly property int maskRadius: Math.ceil(Math.max(0, Math.min(blurRadius, width / 2, height / 2)))
    readonly property var surfaceWindow: Window.window
    readonly property bool frosted: materialEnabled && baseColor.a > 0 && ShellMaterial.blur
    readonly property bool blurActive: frosted && visible && opacity > 0.01 && width > 1 && height > 1 && !!surfaceWindow
    readonly property alias blurMask: blurRegion

    color: ShellMaterial.fill(baseColor, frosted)

    onBlurActiveChanged: ShellMaterial.setBlurClient(surface, blurActive)
    Component.onDestruction: ShellMaterial.setBlurClient(surface, false)

    Region
    {
        id: blurRegion
        item: surface.blurActive ? surface : null
        radius: surface.maskRadius
    }

    Loader
    {
        anchors.fill: parent
        anchors.margins: surface.border.width
        active: surface.visible && surface.materialEnabled && surface.baseColor.a > 0 && String(ShellMaterial.wallpaper) !== ""
        sourceComponent: ClippingRectangle
        {
            color: "transparent"
            radius: Math.max(0, surface.radius - surface.border.width)
            clip: true

            ShellWallpaperTexture
            {
                readonly property Item canvas: surface.surfaceWindow?.contentItem ?? null
                readonly property rect bounds: canvas ? ShellMaterial.boundsIn(parent, canvas) : Qt.rect(0, 0, 0, 0)
                x: -bounds.x
                y: -bounds.y
                width: canvas ? canvas.width : parent.width
                height: canvas ? canvas.height : parent.height
                opacity: ShellMaterial.wallpaperStrength(surface.baseColor)
            }
        }
    }
}
