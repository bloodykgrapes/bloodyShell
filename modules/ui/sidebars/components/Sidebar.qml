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
    readonly property bool floating: Config.barMenu === Enums.MenuFloating
    readonly property real edgeGap: floating ? 10 : 0
    readonly property alias scrollView: viewport
    readonly property alias contentBody: body
    readonly property alias panel: card
    readonly property alias inputRegion: inputMask
    readonly property rect bodyRect: !floating && progress > 0.001 ? Qt.rect(card.x, card.y, card.width, card.height) : Qt.rect(0, 0, 0, 0)
    readonly property real barGap: Math.max(14, Theme.frameSmoothing)
    readonly property real leftInset: Theme.frameThickness + (barSide === Enums.EdgeLeft ? barThickness + barGap : edgeGap)
    readonly property real rightInset: Theme.frameThickness + (barSide === Enums.EdgeRight ? barThickness + barGap : edgeGap)
    readonly property real topInset: Theme.frameThickness + (barSide === Enums.EdgeTop ? barThickness + barGap : verticalBar ? edgeGap : 14)
    readonly property real bottomInset: Theme.frameThickness + (barSide === Enums.EdgeBottom ? barThickness + barGap : verticalBar ? edgeGap : 12)
    readonly property bool verticalBar: barSide === Enums.EdgeLeft || barSide === Enums.EdgeRight
    readonly property bool atRight: verticalBar ? barSide === Enums.EdgeRight : side === "right"
    readonly property bool atBottom: barSide === Enums.EdgeBottom || (verticalBar && side === "right")
    readonly property real panelWidth: Math.max(0, Math.min(Theme.sidebarWidth, width - leftInset - rightInset - 24))
    readonly property real headerHeight: headerLoader.item ? headerLoader.item.implicitHeight + 14 : 0
    readonly property real panelHeight: Math.max(0, Math.min(body.implicitHeight + headerHeight + 36, height - topInset - bottomInset))
    property real progress: opened ? 1 : 0
    Glide on progress {}
    visible: opened || progress > 0.001
    enabled: opened
    onOpenedChanged: if (opened) Qt.callLater(() => sidebar.forceActiveFocus())
    Keys.onEscapePressed: SidebarState.close()

    Region { id: inputMask; item: sidebar.opened ? sidebar : null }

    Item
    {
        id: card
        width: sidebar.panelWidth * (sidebar.verticalBar ? 1 : Math.max(0, Math.min(1, sidebar.progress)))
        height: sidebar.panelHeight * (sidebar.verticalBar ? Math.max(0, Math.min(1, sidebar.progress)) : 1)
        x: sidebar.atRight ? sidebar.width - sidebar.rightInset - width : sidebar.leftInset
        y: sidebar.atBottom ? sidebar.height - sidebar.bottomInset - height : sidebar.topInset
        clip: true

        Rectangle
        {
            anchors.fill: parent
            visible: sidebar.floating
            radius: Theme.barRadius
            color: Theme.frameColor
        }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Item
        {
            width: sidebar.panelWidth
            height: sidebar.panelHeight
            x: !sidebar.verticalBar && sidebar.atRight ? parent.width - width : 0
            y: sidebar.verticalBar && sidebar.atBottom ? parent.height - height : 0
            opacity: sidebar.opened ? 1 : 0
            Appear on opacity {}

            property real expansion: sidebar.opened ? 1 : 0
            Spring on expansion {}
            scale: Config.animationsFluid ? 0.92 + 0.08 * expansion : 1
            transformOrigin: sidebar.atBottom ? (sidebar.atRight ? Item.BottomRight : Item.BottomLeft)
                : (sidebar.atRight ? Item.TopRight : Item.TopLeft)

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
}
