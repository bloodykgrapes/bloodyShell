import QtQuick
import Quickshell
import Quickshell.Wayland

import "../components"
import "../core"
import "../services"

PanelWindow
{
    id: osdWindow

    required property var modelData
    screen: modelData

    readonly property int  side:         Config.osdSide
    readonly property bool isHorizontal: side === Enums.EdgeTop || side === Enums.EdgeBottom

    readonly property bool focused: ServiceCompositor.focusedOutput === "" || !screen || screen.name === ServiceCompositor.focusedOutput
    readonly property bool shown:   focused && ServiceOSD.active

    readonly property bool barHere:   Config.barEnabled && screen !== null && Config.screensShown("barScreens").indexOf(screen.name) >= 0
    readonly property real barDepth:  !barHere ? 0
                                    : side === Config.barSide ? (Config.barType <= Enums.BarFrame ? Theme.barThickness : Theme.barMargin + Theme.barThickness)
                                    : Config.barType === Enums.BarFrame ? Theme.barFrameThickness : 0
    readonly property real edgeGap:   barDepth + Theme.barMargin

    anchors
    {
        top:    side !== Enums.EdgeBottom
        left:   side !== Enums.EdgeRight
        right:  side !== Enums.EdgeLeft
        bottom: side !== Enums.EdgeTop
    }
    implicitHeight: isHorizontal ? (screen ? screen.height : 1000) : 0
    implicitWidth:  isHorizontal ? 0 : (screen ? screen.width : 1000)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: shown || osdWindow.reveal > 0.001
    mask: Region { item: card }

    BackgroundEffect.blurRegion: Theme.blur ? glassRegion : null
    Region { id: glassRegion; Region { item: card; radius: card.radius } }

    function regionsMoved()
    {
        if (mask) mask.changed();
        if (BackgroundEffect.blurRegion) BackgroundEffect.blurRegion.changed();
    }

    property real reveal: shown ? 1 : 0
    Ease on reveal
    {
        duration: osdWindow.shown ? Theme.animationDurationOpen : Theme.animationDurationClose
        curve:    osdWindow.shown ? Theme.easingEmphasized : Theme.easingAccelerate
    }

    readonly property real pad:    Theme.barPadding
    readonly property real padSide: content.value >= 0 ? pad : pad * 2
    readonly property real along:  isHorizontal ? width / 2 : height / 2
    readonly property real slide:  (1 - reveal) * ((isHorizontal ? card.height : card.width) * 0.6 + 12)

    property real cardW: Math.round(content.implicitWidth + padSide * 2)
    property real cardH: Math.round(Math.max(Theme.barThickness, content.implicitHeight + pad))
    Ease on cardW { enabled: Config.animationsEnabled && osdWindow.reveal > 0.01 }
    Ease on cardH { enabled: Config.animationsEnabled && osdWindow.reveal > 0.01 }

    readonly property real depth: edgeGap - slide

    Connections
    {
        target: ServiceOSD
        function onPresentationRevisionChanged() { if (osdWindow.reveal > 0.99 && Config.animationsFluid) bump.restart() }
    }
    SequentialAnimation
    {
        id: bump
        NumberAnimation { target: card; property: "kick"; to: 1; duration: 90;  easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "kick"; to: 0; duration: 260; easing.type: Easing.OutBack }
    }

    Rectangle
    {
        id: card

        property real kick: 0

        width:  osdWindow.cardW
        height: osdWindow.cardH
        x: !osdWindow.isHorizontal ? (osdWindow.side === Enums.EdgeLeft ? osdWindow.depth : osdWindow.width - width - osdWindow.depth) : osdWindow.along - width / 2
        y:  osdWindow.isHorizontal ? (osdWindow.side === Enums.EdgeTop ? osdWindow.depth : osdWindow.height - height - osdWindow.depth) : osdWindow.along - height / 2
        onXChanged: osdWindow.regionsMoved()
        onYChanged: osdWindow.regionsMoved()

        radius: Math.min(Theme.barRadius, height / 2)
        color: Theme.barSurface
        border.width: Theme.borderWidth
        border.color: Theme.barSurfaceEdge

        opacity: Math.min(1, osdWindow.reveal * 1.4)
        scale: (0.9 + 0.1 * osdWindow.reveal) * (1 + 0.03 * kick)
        transformOrigin: osdWindow.side === Enums.EdgeTop ? Item.Top : osdWindow.side === Enums.EdgeBottom ? Item.Bottom : osdWindow.side === Enums.EdgeLeft ? Item.Left : Item.Right

        Item
        {
            id: valueFill

            readonly property real inset: 4

            x: inset
            y: inset
            width: parent.width - inset * 2
            height: parent.height - inset * 2
            visible: content.value >= 0

            property real fill: Math.max(0, Math.min(1, content.value))
            Behavior on fill { enabled: Config.animationsEnabled && osdWindow.reveal > 0.99; NumberAnimation { duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized } }

            Item
            {
                clip: true
                width: valueFill.width * valueFill.fill
                height: valueFill.height

                Rectangle
                {
                    width: valueFill.width
                    height: valueFill.height
                    radius: Math.max(0, card.radius - valueFill.inset)
                    color: Theme.accentShell ? Theme.accentAlpha(content.dim ? 0.16 : 0.38) : Theme.inkAlpha(content.dim ? 0.08 : 0.2)
                }
            }
        }

        OSDContent
        {
            id: content

            x: Math.round(osdWindow.isHorizontal ? osdWindow.along - width / 2 : card.x + (card.width - width) / 2) - card.x
            y: Math.round(osdWindow.isHorizontal ? card.y + (card.height - height) / 2 : osdWindow.along - height / 2) - card.y
        }
    }
}
