import QtQuick

import ".."
import "../../core"
import "../../services"
import "../bar"

Item
{
    id: dockPopup

    required property var host
    property var    target: null
    property string mode: ""

    readonly property bool open: target !== null && mode !== ""

    property var    shown: null
    property string shownMode: ""
    onTargetChanged: if (target) shown = target
    onModeChanged: if (mode !== "") shownMode = mode

    readonly property bool horizontal: host.isHorizontal
    readonly property int  side: Config.dockSide

    readonly property real gap: host.zoomOverflow

    readonly property var windows:
    {
        if (!shown) return [];
        try { return JSON.parse(shown.windowsJson); } catch (e) { return []; }
    }

    readonly property real wantW: content.item ? content.item.implicitWidth : 0
    readonly property real wantH: content.item ? content.item.implicitHeight : 0
    property real panelW: wantW
    property real panelH: wantH
    Glide on panelW { enabled: Config.animationsEnabled && dockPopup.morph }
    Glide on panelH { enabled: Config.animationsEnabled && dockPopup.morph }

    readonly property bool morph: sheet.opacity > 0.5

    width:  horizontal ? panelW : panelW + gap
    height: horizontal ? panelH + gap : panelH

    readonly property point anchorPoint: shown ? shown.mapToItem(parent, shown.width / 2, shown.height / 2) : Qt.point(0, 0)
    readonly property var container: host.container

    readonly property real targetCenterX: Math.max(8 + width / 2,
        Math.min(parent.width - 8 - width / 2, anchorPoint.x))
    readonly property real targetCenterY: Math.max(8 + height / 2,
        Math.min(parent.height - 8 - height / 2, anchorPoint.y))

    property real centerX: targetCenterX
    property real centerY: targetCenterY

    x: Math.round(horizontal
        ? centerX - width / 2
        : (side === Enums.EdgeLeft ? container.restX + container.width : container.restX - width))

    y: Math.round(horizontal
        ? (side === Enums.EdgeTop ? container.restY + container.height : container.restY - height)
        : centerY - height / 2)

    Glide on centerX
    {
        enabled: Config.animationsEnabled && dockPopup.morph && dockPopup.horizontal
    }

    Glide on centerY
    {
        enabled: Config.animationsEnabled && dockPopup.morph && !dockPopup.horizontal
    }

    visible: sheet.opacity > 0.01

    HoverHandler { id: hover }
    readonly property bool hovered: hover.hovered

    Item
    {
        id: sheet

        x: dockPopup.horizontal ? 0 : (dockPopup.side === Enums.EdgeLeft ? dockPopup.gap : 0)
        y: dockPopup.horizontal ? (dockPopup.side === Enums.EdgeTop ? dockPopup.gap : 0) : 0
        width: dockPopup.panelW
        height: dockPopup.panelH

        property real offset: dockPopup.open ? 0 : 8
        opacity: dockPopup.open ? 1 : 0

        Smooth on opacity { duration: dockPopup.open ? 160 : 110 }
        Glide on offset {}

        transform: Translate
        {
            x: dockPopup.horizontal ? 0 : (dockPopup.side === Enums.EdgeLeft ? -sheet.offset : sheet.offset)
            y: dockPopup.horizontal ? (dockPopup.side === Enums.EdgeTop ? -sheet.offset : sheet.offset) : 0
        }

        Rectangle
        {
            id: card

            anchors.fill: parent
            radius: 14
            clip: true

            color: Theme.colorSolid
            border.color: Theme.colorLine
            border.width: Theme.borderWidth

            MouseArea { anchors.fill: parent }

            Loader
            {
                id: content
                sourceComponent: body
            }
        }
    }

    component Header: Item
    {
        width: parent ? parent.width : 200
        height: 34

        Image
        {
            id: headIcon
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            width: 18; height: 18
            sourceSize.width: 36; sourceSize.height: 36
            source: dockPopup.shown ? ServiceApplications.iconFor(dockPopup.shown.appId) : ""
            asynchronous: true
            mipmap: true
        }

        ShellText
        {
            anchors { left: headIcon.right; leftMargin: 8; right: count.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            label: dockPopup.shown && dockPopup.shown.displayName ? dockPopup.shown.displayName : ""
            size: 13
            color: Theme.text1
            font.weight: Font.Medium
        }

        ShellText
        {
            id: count
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            label: dockPopup.windows.length > 1 ? Tr.tr("dock.windows").arg(dockPopup.windows.length) : ""
            size: 11
            color: Theme.text3
        }
    }

    component WindowRow: Rectangle
    {
        id: row

        required property var modelData
        readonly property bool hot: rowArea.containsMouse || closeArea.containsMouse

        width: parent ? parent.width : 200
        height: 32
        radius: Theme.radiusMedium

        color: modelData.focused ? (hot ? Theme.colorPressed : Theme.colorField) : (hot ? Theme.colorHover : "transparent")
        Tint on color {}

        Rectangle
        {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            width: 6; height: 6; radius: 3
            color: row.modelData.urgent ? Theme.colorAttention : row.modelData.focused ? Theme.colorAccent : Theme.text4
        }

        ShellText
        {
            anchors { left: parent.left; leftMargin: 24; right: closeButton.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
            label: row.modelData.title || Tr.tr("dock.window")
            color: row.modelData.focused ? Theme.text1 : Theme.text2
        }

        MouseArea
        {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            onClicked: mouse =>
            {
                if (mouse.button === Qt.MiddleButton) { ServiceCompositor.closeWindow(row.modelData.id); return; }
                ServiceCompositor.focusWindow(row.modelData.id);
                dockPopup.host.popupClose();
            }
        }

        Rectangle
        {
            id: closeButton

            anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
            width: 22; height: 22; radius: 11

            opacity: row.hot ? 1 : 0
            color: closeArea.containsMouse ? Theme.colorPressed : "transparent"
            Smooth on opacity {}

            ShellIcon { anchors.centerIn: parent; icon: Icon.close; size: 12 }

            MouseArea
            {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ServiceCompositor.closeWindow(row.modelData.id)
            }
        }
    }

    Component
    {
        id: body

        Item
        {
            id: bodyRoot

            readonly property bool expanded: dockPopup.shownMode === "menu"

            readonly property real baseWidth: dockPopup.windows.length > 0 ? 250 : Math.min(250, Math.ceil(headerProbe.advanceWidth) + 72)
            implicitWidth: expanded ? Math.max(baseWidth, 210) : baseWidth
            implicitHeight: rows.implicitHeight + 12

            TextMetrics
            {
                id: headerProbe
                font.family: Theme.fontText
                font.pixelSize: Math.round(13 * Config.themeScale)
                text: dockPopup.shown && dockPopup.shown.displayName ? dockPopup.shown.displayName : ""
            }

            Column
            {
                id: rows
                x: 6
                y: 6
                width: parent.implicitWidth - 12
                spacing: 2

                Header { }

                Repeater
                {
                    model: dockPopup.windows.slice(0, 8)
                    WindowRow { }
                }

                Item
                {
                    id: fold

                    readonly property real overhang: 6
                    x: -overhang
                    width: parent.width + overhang * 2
                    height: bodyRoot.expanded ? actions.implicitHeight + 2 : 0
                    clip: true
                    enabled: bodyRoot.expanded

                    Column
                    {
                        id: actions

                        x: fold.overhang
                        y: 1
                        width: parent.width - fold.overhang * 2
                        spacing: 2

                        opacity: fold.enabled ? 1 : 0
                        Smooth on opacity { duration: fold.enabled ? 220 : 90 }

                        MenuSeparator { }

                        MenuItem
                        {
                            icon: Icon.add
                            text: dockPopup.windows.length > 0 ? Tr.tr("dock.newWindow") : Tr.tr("common.open")
                            onClicked:
                            {
                                ServiceApplications.launch(dockPopup.shown.appId);
                                dockPopup.host.popupClose();
                            }
                        }

                        MenuItem
                        {
                            readonly property bool pinned: !!dockPopup.shown && dockPopup.shown.isPinned === true
                            readonly property string appId: dockPopup.shown && dockPopup.shown.appId ? dockPopup.shown.appId : ""
                            visible: appId !== "" && !appId.startsWith("id:")

                            icon: pinned ? Icon.unpin : Icon.pin
                            text: pinned ? Tr.tr("dock.unpinFromDock") : Tr.tr("dock.pinToDock")
                            onClicked:
                            {
                                const id = dockPopup.shown.appId;
                                dockPopup.host.popupClose();
                                if (pinned) ServiceDock.unpin(id);
                                else ServiceDock.pinAt(id, ServiceDock.pinned.length);
                            }
                        }

                        MenuSeparator { visible: dockPopup.windows.length > 0 }

                        MenuItem
                        {
                            visible: dockPopup.windows.length > 0
                            danger: true
                            icon: Icon.close
                            text: dockPopup.windows.length > 1 ? Tr.tr("dock.closeAllWindows").arg(dockPopup.windows.length) : Tr.tr("dock.closeWindow")
                            onClicked:
                            {
                                ServiceDock.closeAll(dockPopup.shown.modelData);
                                dockPopup.host.popupClose();
                            }
                        }
                    }
                }
            }
        }
    }
}
