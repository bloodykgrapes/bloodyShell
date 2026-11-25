import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Widgets

import "../animations"
import "../core"

Rectangle
{
    id: surface

    property color baseColor: Theme.colorSolid
    property bool materialEnabled: true
    property bool transitionMaterial: false
    property real blurRadius: radius
    readonly property int maskRadius: Math.ceil(Math.max(0, Math.min(blurRadius, width / 2, height / 2)))
    readonly property var surfaceWindow: Window.window
    readonly property bool frosted: materialEnabled && baseColor.a > 0 && ShellMaterial.blur
    readonly property bool blurActive: frosted && visible && opacity > 0.01 && width > 1 && height > 1 && !!surfaceWindow
    readonly property rect blurBounds: blurActive ? ShellMaterial.boundsIn(surface, surfaceWindow.contentItem) : Qt.rect(0, 0, 0, 0)
    readonly property alias blurMask: blurRegion

    property int blurFrames: 0
    property real blurMix: frosted && (!transitionMaterial || blurFrames >= 2) ? 1 : 0
    readonly property color blurTint: ShellMaterial.fill(baseColor, frosted)
    color: Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a + (blurTint.a - baseColor.a) * blurMix)

    onBlurActiveChanged:
    {
        blurFrames = 0;
        ShellMaterial.setBlurClient(surface, blurActive);
    }
    onSurfaceWindowChanged: blurFrames = 0
    Component.onDestruction: ShellMaterial.setBlurClient(surface, false)

    // Keep the opaque tint through the first frame while the compositor receives the mask.
    FrameAnimation
    {
        running: surface.transitionMaterial && surface.blurActive && surface.surfaceWindow?.visible && surface.blurFrames < 2
        onTriggered: surface.blurFrames++
    }
    Smooth on blurMix
    {
        enabled: Config.animationsEnabled && surface.transitionMaterial && surface.blurActive && surface.blurFrames >= 2
        duration: 100
    }

    Region
    {
        id: blurRegion
        // An item-backed Region misses movement of its ancestors.
        x: Math.round(surface.blurBounds.x)
        y: Math.round(surface.blurBounds.y)
        width: Math.max(0, Math.round(surface.blurBounds.x + surface.blurBounds.width) - x)
        height: Math.max(0, Math.round(surface.blurBounds.y + surface.blurBounds.height) - y)
        radius: surface.blurActive ? Math.round(surface.maskRadius * Math.min(surface.blurBounds.width / surface.width,
            surface.blurBounds.height / surface.height)) : 0
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
                property real blend: status === Image.Ready ? 1 : 0
                Smooth on blend { enabled: Config.animationsEnabled && surface.transitionMaterial; duration: 100 }
                readonly property Item canvas: surface.surfaceWindow?.contentItem ?? null
                readonly property rect bounds: canvas ? ShellMaterial.boundsIn(parent, canvas) : Qt.rect(0, 0, 0, 0)
                x: -bounds.x
                y: -bounds.y
                width: canvas ? canvas.width : parent.width
                height: canvas ? canvas.height : parent.height
                opacity: blend * ShellMaterial.wallpaperStrength(surface.baseColor)
            }
        }
    }
}
