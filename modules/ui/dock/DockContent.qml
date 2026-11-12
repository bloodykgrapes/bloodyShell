pragma ComponentBehavior: Bound

import QtQuick

import "../../animations"
import "../../core"
import "../../services"
import "components"

Item
{
    id: content

    required property var host

    readonly property alias container: dockContainer
    readonly property alias view: dockView
    readonly property bool hovered: containerHover.hovered

    Rectangle
    {
        id: dockContainer
        objectName: "dockSurface"

        readonly property real length: (content.host.isHorizontal ? dockView.contentWidth : dockView.contentHeight) + Theme.dockPadding * 2

        visible: content.host.initialized && ServiceDock.model.count > 0

        width:  content.host.isHorizontal ? length : content.host.thickness
        height: content.host.isHorizontal ? content.host.thickness : length
        radius: Math.min(Theme.dockRadius, content.host.thickness / 2)

        color: content.host.islands ? Theme.frameColor : "transparent"

        readonly property real hidden: content.host.inFrame ? content.host.thickness + content.host.edgeGap + Theme.barRadius
                                                   : content.host.thickness + content.host.edgeGap + 4
        property real reveal: content.host.revealed ? 1 : 0
        Glide on reveal { enabled: Config.animationsEnabled && content.host.initialized }

        opacity: Math.min(1, reveal * 1.6)

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
            opacity: content.host.inFrame ? Math.min(1, dockContainer.reveal * 1.6) : 1
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
