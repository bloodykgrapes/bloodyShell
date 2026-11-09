pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../../animations"
import "../../../core"

FocusScope
{
    id: sidebar

    required property var screen
    required property string side
    property int barSide: -1
    property real barThickness: 0
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
    readonly property real topInset: Theme.frameThickness + (barSide === Enums.EdgeTop ? barThickness + barGap : 14)
    readonly property real bottomInset: Theme.frameThickness + (barSide === Enums.EdgeBottom ? barThickness + barGap : 12)
    readonly property real panelWidth: Math.max(0, Math.min(Theme.sidebarWidth, width - leftInset - rightInset - 24))
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
        width: sidebar.panelWidth * Math.max(0, Math.min(1, sidebar.progress))
        height: Math.max(0, Math.min(body.implicitHeight + 36, sidebar.height - y - sidebar.bottomInset))
        x: sidebar.side === "left" ? sidebar.leftInset : sidebar.width - sidebar.rightInset - width
        y: sidebar.topInset
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
            height: parent.height
            x: sidebar.side === "left" ? 0 : parent.width - width
            opacity: sidebar.opened ? 1 : 0
            Appear on opacity {}

            property real expansion: sidebar.opened ? 1 : 0
            Spring on expansion {}
            scale: Config.animationsFluid ? 0.92 + 0.08 * expansion : 1
            transformOrigin: sidebar.side === "left" ? Item.Left : Item.Right

            Flickable
            {
                id: viewport
                anchors { fill: parent; margins: 4 }
                contentWidth: width
                contentHeight: body.implicitHeight + 28
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                clip: true

                Column { id: body; x: 14; y: 14; width: viewport.width - 28; spacing: 14 }
            }
        }
    }
}
