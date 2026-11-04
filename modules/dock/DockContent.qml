pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../components"
import "../components/dock"
import "../core"
import "../services"

Item
{
    id: content

    readonly property bool glassContent: Theme.blur

    required property var host

    readonly property alias container: dockContainer
    readonly property alias view: dockView
    readonly property alias glass: glassRegion
    readonly property bool  hovered: containerHover.hovered

    Region
    {
        id: glassRegion
        Region { item: dockContainer; radius: dockContainer.radius }
        Region { item: glassFramePiece }
    }
    Item
    {
        id: glassFramePiece
        x: !content.host.framed ? 0 : content.host.isHorizontal ? merged.x : (content.host.side === Enums.EdgeLeft ? 0 : content.host.width - content.host.frameThickness)
        y: !content.host.framed ? 0 : !content.host.isHorizontal ? merged.y : (content.host.side === Enums.EdgeTop ? 0 : content.host.height - content.host.frameThickness)
        width:  !content.host.framed ? 0 : content.host.isHorizontal ? merged.width : content.host.frameThickness
        height: !content.host.framed ? 0 : content.host.isHorizontal ? content.host.frameThickness : merged.height
    }

    ShaderEffect
    {
        id: merged

        visible: content.host.attached && dockContainer.visible

        readonly property real pad: Theme.barRadius + 6
        readonly property real depth: content.host.thickness + content.host.attach + 6
        x: content.host.isHorizontal ? dockContainer.restX - pad : (content.host.side === Enums.EdgeLeft ? 0 : content.host.width - depth)
        y: !content.host.isHorizontal ? dockContainer.restY - pad : (content.host.side === Enums.EdgeTop ? 0 : content.host.height - depth)
        width:  content.host.isHorizontal ? dockContainer.width + pad * 2 : depth
        height: content.host.isHorizontal ? depth : dockContainer.height + pad * 2

        function inset(edge) { return edge === content.host.side && !content.host.onFloating ? content.host.ground : -400 }
        function local(r) { return r.width > 0 ? Qt.rect(r.x - x, r.y - y, r.width, r.height) : Qt.rect(0, 0, 0, 0) }

        property size     size: Qt.size(width, height)
        property vector4d inner: Qt.vector4d(inset(2), inset(0), inset(3), inset(1))
        property real     innerRadius: 0

        property rect island0: Qt.rect(dockContainer.x - x, dockContainer.y - y, dockContainer.width, dockContainer.height)
        property rect island1: content.host.onFloating && content.host.attached ? local(content.host.barArea) : Qt.rect(0, 0, 0, 0)
        property rect island2: Qt.rect(0, 0, 0, 0)
        property real islandRadius: Math.min(dockContainer.radius, Theme.barRadius)

        property rect panel0: Qt.rect(0, 0, 0, 0)
        property rect panel1: Qt.rect(0, 0, 0, 0)
        property rect panel2: Qt.rect(0, 0, 0, 0)
        property real panelRadius: Theme.barRadius
        property real smoothing: Theme.barRadius
        property real panelSmoothing: Theme.barRadius

        property real  borderWidth: Theme.borderWidth
        property color fillColor: Theme.barSurface
        property color borderColor: Theme.barSurfaceEdge

        property rect  cut: local(content.host.barArea)

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/bar.frag.qsb")

        readonly property var cutRect: visible && content.host.framed ? { "x": x, "y": y, "w": width, "h": height } : null

        property string cutScreen: ""
        function publishCut()
        {
            const name = content.host.screen ? content.host.screen.name : "";
            if (cutScreen !== "" && cutScreen !== name) SurfaceState.setDockCut(cutScreen, null);
            cutScreen = name;
            if (name !== "") SurfaceState.setDockCut(name, cutRect);
        }
        onCutRectChanged: publishCut()
        Connections { target: content.host; function onScreenChanged() { merged.publishCut() } }
        Component.onDestruction: if (cutScreen !== "") SurfaceState.setDockCut(cutScreen, null)
    }

    Rectangle
    {
        id: dockContainer

        readonly property real length: (content.host.isHorizontal ? dockView.contentWidth : dockView.contentHeight) + Theme.dockPadding * 2

        visible: content.host.initialized && ServiceDock.model.count > 0

        width:  content.host.isHorizontal ? length : content.host.thickness
        height: content.host.isHorizontal ? content.host.thickness : length
        radius: Math.min(Theme.dockRadius, content.host.thickness / 2)

        color: content.host.attached ? "transparent" : Theme.dockSurface
        border.color: Theme.dockSurfaceEdge
        border.width: content.host.attached ? 0 : Theme.borderWidth

        readonly property real hidden: content.host.attached ? content.host.thickness + content.host.attach + Theme.barRadius
                                                   : content.host.thickness + content.host.edgeGap + 4
        property real reveal: content.host.revealed ? 1 : 0
        Glide on reveal { enabled: Config.animationsEnabled && content.host.initialized }

        opacity: content.host.attached ? 1 : Math.min(1, reveal * 1.6)

        readonly property real restX: Math.round(content.host.isHorizontal ? (content.host.width - width) / 2
            : content.host.side === Enums.EdgeLeft ? content.host.edgeGap : content.host.width - width - content.host.edgeGap)
        readonly property real restY: Math.round(!content.host.isHorizontal ? (content.host.height - height) / 2
            : content.host.side === Enums.EdgeTop ? content.host.edgeGap : content.host.height - height - content.host.edgeGap)

        readonly property real slide: Math.round((1 - reveal) * hidden)
        x: restX + (content.host.isHorizontal ? 0 : content.host.side === Enums.EdgeLeft ? -slide : slide)
        y: restY + (!content.host.isHorizontal ? 0 : content.host.side === Enums.EdgeTop ? -slide : slide)

        HoverHandler { id: containerHover }

        ListView
        {
            id: dockView

            property real dragMouseCoord: 0
            property bool dragActive: false

            x: Theme.dockPadding
            y: Theme.dockPadding
            opacity: content.host.attached ? Math.min(1, dockContainer.reveal * 1.6) : 1
            width:  content.host.isHorizontal ? contentWidth : content.host.base
            height: content.host.isHorizontal ? content.host.base : contentHeight

            interactive: false
            orientation: content.host.isHorizontal ? ListView.Horizontal : ListView.Vertical
            spacing: Theme.dockSpacing

            clip: false

            model: ServiceDock.model

            add: Transition
            {
                enabled: Config.animationsEnabled
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animationDurationDock; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.6; to: 1; duration: Theme.animationDurationDock; easing.type: Easing.OutBack }
            }
            remove: Transition
            {
                enabled: Config.animationsEnabled
                NumberAnimation { property: "opacity"; to: 0; duration: Math.max(100, Theme.animationDurationDock * 0.7); easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; to: 0.6; duration: Math.max(100, Theme.animationDurationDock * 0.7); easing.type: Easing.InCubic }
            }
            displaced: Transition
            {
                enabled: Config.animationsEnabled
                NumberAnimation { property: content.host.isHorizontal ? "x" : "y"; duration: Theme.animationDurationDock + 50; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
            }

            delegate: Loader
            {
                id: slot

                required property int index
                required property var modelData

                z: item && item.dragging ? 100 : 0

                sourceComponent: modelData.type === "separator" ? separatorComp : appComp

                Component
                {
                    id: separatorComp

                    Item
                    {
                        readonly property bool hot: dockView.dragActive

                        width:  content.host.isHorizontal ? Theme.dockSeparatorSize : content.host.base
                        height: content.host.isHorizontal ? content.host.base : Theme.dockSeparatorSize

                        Rectangle
                        {
                            anchors.centerIn: parent
                            width:  content.host.isHorizontal ? (parent.hot ? 2 : 1) : Math.round(content.host.base * 0.6)
                            height: content.host.isHorizontal ? Math.round(content.host.base * 0.6) : (parent.hot ? 2 : 1)
                            radius: 1
                            color: parent.hot ? Theme.text3 : Theme.colorLine
                            Tint on color {}
                        }
                    }
                }

                Component
                {
                    id: appComp

                    DockItem
                    {
                        host: content.host
                        view: dockView
                        index: slot.index
                        modelData: slot.modelData
                    }
                }
            }
        }
    }
}
