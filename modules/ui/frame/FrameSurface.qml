import QtQuick
import Quickshell

import "../../common"
import "../../core"
import "FrameJoinGeometry.js" as JoinGeometry

ShaderEffect
{
    id: frame

    property bool materialEnabled: false
    property real thickness: Theme.frameThickness
    property rect startBody: Qt.rect(0, 0, 0, 0)
    property rect centerBody: Qt.rect(0, 0, 0, 0)
    property rect endBody: Qt.rect(0, 0, 0, 0)
    property rect centerPanel: Qt.rect(0, 0, 0, 0)
    property rect dockBody: Qt.rect(0, 0, 0, 0)
    property bool barAttached: Config.barAttach
    property bool dockAttached: Config.dockAttach
    readonly property vector2d bodyCurves: Qt.vector2d(
        barAttached ? JoinGeometry.curveScale(Config.barAttachCurve) : 0,
        dockAttached ? JoinGeometry.curveScale(Config.dockAttachCurve) : 0)

    readonly property vector2d screenSize: Qt.vector2d(width, height)
    readonly property real inset: frosted ? Math.floor(thickness) : thickness
    property real cornerRadius: Theme.frameRadius
    readonly property real barRadius: Theme.barRadius
    readonly property real menuRadius: Theme.menuRadius
    readonly property real menuSide: Config.barSide
    // The shader and the Wayland mask consume the same rounded geometry.
    readonly property rect startShape: startRegion.bounds
    readonly property vector4d startCorners: startRegion.corners
    readonly property vector4d startFillets: startRegion.fillets
    readonly property rect centerShape: centerRegion.bounds
    readonly property vector4d centerCorners: centerRegion.corners
    readonly property vector4d centerFillets: centerRegion.fillets
    readonly property rect endShape: endRegion.bounds
    readonly property vector4d endCorners: endRegion.corners
    readonly property vector4d endFillets: endRegion.fillets
    readonly property rect panelShape: panelRegion.bounds
    readonly property vector4d panelCorners: panelRegion.corners
    readonly property vector4d panelFillets: panelRegion.fillets
    readonly property rect dockShape: dockRegion.bounds
    readonly property vector4d dockCorners: dockRegion.corners
    readonly property vector4d dockFillets: dockRegion.fillets
    readonly property vector4d centerJoin: centerAttachment.geometry
    property color fillColor: Theme.frameColor
    readonly property bool frosted: materialEnabled && ShellMaterial.blur
    readonly property color paintColor: ShellMaterial.fill(fillColor, frosted)
    readonly property Item wallpaperTexture: wallpaper
    readonly property real wallpaperStrength: wallpaper.status === Image.Ready ? ShellMaterial.wallpaperStrength(fillColor) : 0
    property real blurGrain: frosted ? ShellMaterial.blurGrain : 0
    readonly property vector2d wallpaperScale:
    {
        const aspect = width / Math.max(1, height);
        const imageAspect = wallpaper.implicitWidth / Math.max(1, wallpaper.implicitHeight);
        return Qt.vector2d(Math.min(1, aspect / Math.max(0.01, imageAspect)), Math.min(1, imageAspect / Math.max(0.01, aspect)));
    }
    property real borderWidth: Theme.panelBorderWidth
    property color borderColor: Theme.colorPanelEdge
    readonly property alias blurMask: mask

    fragmentShader: Qt.resolvedUrl("../../../assets/shaders/frame.frag.qsb")

    ShellWallpaperTexture
    {
        id: wallpaper
        source: frame.materialEnabled ? ShellMaterial.wallpaper : ""
        visible: false
    }

    Region
    {
        id: mask

        Region
        {
            item: frame.frosted && frame.thickness >= 1 ? frame : null
            Region
            {
                intersection: Intersection.Subtract
                x: frame.inset
                y: x
                width: Math.max(0, Math.ceil(frame.width) - x * 2)
                height: Math.max(0, Math.ceil(frame.height) - y * 2)
                radius: frame.cornerRadius
            }
        }
        FrameBodyBlurRegion { id: startRegion; surface: frame; area: frame.startBody; bodyRadius: frame.barRadius; curveScale: frame.bodyCurves.x }
        FrameBodyBlurRegion { id: centerRegion; surface: frame; area: frame.centerBody; bodyRadius: frame.barRadius; curveScale: frame.bodyCurves.x }
        FrameBodyBlurRegion { id: endRegion; surface: frame; area: frame.endBody; bodyRadius: frame.barRadius; curveScale: frame.bodyCurves.x }
        FrameBodyBlurRegion
        {
            id: panelRegion
            surface: frame
            area: frame.centerPanel
            bodyRadius: frame.menuRadius
            joinLimit: frame.barRadius
            curveScale: frame.bodyCurves.x
        }
        FrameBodyBlurRegion { id: dockRegion; surface: frame; area: frame.dockBody; bodyRadius: Theme.dockRadius; curveScale: frame.bodyCurves.y }

        FrameMenuJoinRegion { id: centerAttachment; surface: frame; bar: frame.centerBody; menu: frame.centerPanel }
    }
}
