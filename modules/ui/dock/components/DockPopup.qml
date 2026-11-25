import QtQuick

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"

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

    MenuReveal
    {
        id: sheet
        objectName: "dockPopupReveal"

        x: dockPopup.horizontal ? 0 : (dockPopup.side === Enums.EdgeLeft ? dockPopup.gap : 0)
        y: dockPopup.horizontal ? (dockPopup.side === Enums.EdgeTop ? dockPopup.gap : 0) : 0
        width: dockPopup.panelW
        height: dockPopup.panelH
        radius: Theme.menuControlRadius
        origin: dockPopup.horizontal ? Qt.point(0.5, dockPopup.side === Enums.EdgeTop ? 0 : 1)
            : Qt.point(dockPopup.side === Enums.EdgeLeft ? 0 : 1, 0.5)

        property real reveal: dockPopup.open ? 1 : 0
        progress: Config.animationsEnabled ? reveal : dockPopup.open ? 1 : 0
        Ease on reveal
        {
            duration: dockPopup.open ? Theme.animationDurationControl : Theme.animationDurationClose
            curve: dockPopup.open ? Theme.easingEmphasized : Theme.easingAccelerate
        }

        MouseArea { anchors.fill: parent }

        Loader
        {
            id: content
            sourceComponent: body
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

    component WindowRow: ButtonList
    {
        id: row
        objectName: "dockWindowRow"

        required property var modelData
        icon: modelData.urgent ? Icon.bellON : ""
        trailingIcon: modelData.focused ? Icon.check : ""
        text: modelData.title || Tr.tr("dock.window")
        Accessible.selected: modelData.focused

        onClicked:
        {
            ServiceCompositor.focusWindow(modelData.id);
            dockPopup.host.popupClose();
        }

        property TapHandler middleClick: TapHandler
        {
            parent: row
            acceptedButtons: Qt.MiddleButton
            onTapped: ServiceCompositor.closeWindow(row.modelData.id)
        }

        Button
        {
            compact: true
            objectName: "dockWindowClose"
            icon: Icon.close
            text: Tr.tr("dock.closeWindow")
            danger: true
            onClicked: ServiceCompositor.closeWindow(row.modelData.id)
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
                font.pixelSize: 13
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

                        ButtonList
                        {
                            icon: Icon.add
                            text: dockPopup.windows.length > 0 ? Tr.tr("dock.newWindow") : Tr.tr("common.open")
                            onClicked:
                            {
                                ServiceApplications.launch(dockPopup.shown.appId);
                                dockPopup.host.popupClose();
                            }
                        }

                        ButtonList
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

                        ButtonList
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
