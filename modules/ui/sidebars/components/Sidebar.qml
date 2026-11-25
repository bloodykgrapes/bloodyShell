pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../../common"
import "../../../animations"
import "../../../core"

FocusScope
{
    id: sidebar

    required property var screen
    required property string side
    property int barSide: -1
    property real barThickness: 0
    property Component header: null
    default property alias content: body.data

    readonly property bool opened: SidebarState.current === side && screen && SidebarState.onOutput(screen.name)
    readonly property alias scrollView: viewport
    readonly property alias contentBody: body
    readonly property alias panel: card
    readonly property alias inputRegion: inputMask
    readonly property alias popupLayer: popupSurface
    readonly property real frameInset: Theme.frameThickness + Theme.panelGap
    readonly property real leftInset: frameInset + (barSide === Enums.EdgeLeft ? barThickness : 0)
    readonly property real rightInset: frameInset + (barSide === Enums.EdgeRight ? barThickness : 0)
    readonly property real topInset: frameInset + (barSide === Enums.EdgeTop ? barThickness : 0)
    readonly property real bottomInset: frameInset + (barSide === Enums.EdgeBottom ? barThickness : 0)
    readonly property bool verticalBar: barSide === Enums.EdgeLeft || barSide === Enums.EdgeRight
    readonly property bool atRight: verticalBar ? barSide === Enums.EdgeRight : side === "right"
    readonly property bool atBottom: barSide === Enums.EdgeBottom || (verticalBar && side === "right")
    readonly property real panelWidth: Math.max(0, Math.min(Theme.sidebarWidth, width - leftInset - rightInset - 24))
    readonly property real headerHeight: headerLoader.item ? headerLoader.item.implicitHeight + 14 : 0
    readonly property real panelHeight: Math.max(0, Math.min(body.implicitHeight + headerHeight + 36, height - topInset - bottomInset))
    readonly property real progress: reveal.progress
    readonly property real crossProgress: progress * (1.5 - 0.5 * progress)
    visible: opened || progress > 0
    enabled: opened
    onOpenedChanged: if (opened) Qt.callLater(() => sidebar.forceActiveFocus())
    Keys.onEscapePressed: SidebarState.close()

    Region { id: inputMask; item: sidebar.opened ? sidebar : null }

    EdgeReveal { id: reveal; opened: sidebar.opened }

    FloatingPanelSurface
    {
        anchors.fill: card
        visible: card.visible
        reveal: sidebar.progress
    }

    Item
    {
        id: card
        width: sidebar.panelWidth * (sidebar.verticalBar ? sidebar.crossProgress : sidebar.progress)
        height: sidebar.panelHeight * (sidebar.verticalBar ? sidebar.progress : sidebar.crossProgress)
        x: sidebar.atRight ? sidebar.width - sidebar.rightInset - width : sidebar.leftInset
        y: sidebar.atBottom ? sidebar.height - sidebar.bottomInset - height : sidebar.topInset
        visible: width > 1 && height > 1
        clip: true

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Item
        {
            width: sidebar.panelWidth
            height: sidebar.panelHeight
            x: sidebar.atRight ? parent.width - width : 0
            y: sidebar.atBottom ? parent.height - height : 0
            opacity: reveal.contentOpacity

            Loader
            {
                id: headerLoader
                x: 18; y: 18
                width: sidebar.panelWidth - 36
                height: item ? item.implicitHeight : 0
                sourceComponent: sidebar.header
            }

            Flickable
            {
                id: viewport
                anchors { fill: parent; margins: 4; topMargin: sidebar.headerHeight + 4 }
                contentWidth: width
                contentHeight: body.implicitHeight + 28
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                clip: true

                SmoothScroll { view: viewport }

                Column { id: body; x: 14; y: 14; width: viewport.width - 28; spacing: 14 }
            }
        }
    }

    Item { id: popupSurface; anchors.fill: parent }
}
