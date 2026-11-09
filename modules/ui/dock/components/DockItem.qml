import QtQuick
import QtQuick.Window

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"

MouseArea
{
    id: dockItem

    RenderActivity
    {
        id: activity
        target: dockItem
    }

    required property var host
    required property var view
    required property int index
    required property var modelData

    readonly property bool horizontal: host.isHorizontal
    readonly property int  side: Config.dockSide
    readonly property real base: Config.dockIconSize

    readonly property string windowId: String(modelData?.id ?? "")
    readonly property bool   isRunning: modelData?.is_running ?? false
    readonly property bool   isFocused: modelData?.is_focused ?? false
    readonly property bool   isPinned: modelData?.is_pinned ?? false
    readonly property bool   isUrgent: modelData?.is_urgent ?? false
    readonly property string appId: modelData?.app_id ?? ""
    readonly property string windowTitle: modelData?.title ?? ""
    readonly property int    windowCount: modelData?.count ?? 0
    readonly property int    focusedIndex: modelData?.focused_index ?? -1
    readonly property string windowsJson: modelData?.windows ?? "[]"

    readonly property string displayName: ServiceApplications.appName(appId, windowTitle)
    readonly property bool   launching: !isRunning && ServiceApplications.isLaunching(appId)
    readonly property int    badge: Config.dockBadges && !isFocused ? ServiceDock.badgeCount(appId) : 0

    width: base
    height: base

    hoverEnabled: true
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onWheel: wheel => ServiceDock.cycleWindow(modelData, wheel.angleDelta.y > 0 ? -1 : 1)

    onContainsMouseChanged:
    {
        if (containsMouse) host.previewEnter(dockItem);
        else host.previewLeave(dockItem);
    }

    property bool dragging: false
    property bool moved: false
    property real grabCoord: 0
    property real pressCoord: 0
    property real pressCross: 0
    property real crossOffset: 0

    readonly property real dragCoord: Math.max(0, Math.min((horizontal ? view.width : view.height) - base, view.dragMouseCoord - grabCoord))

    readonly property string dropAction:
    {
        if (!dragging) return "";
        if (isPinned && crossOffset > base * 1.2) return "unpin";
        const sep = host.separatorItem();
        if (!sep) return "";
        const sepCenter = (horizontal ? sep.x + sep.width / 2 : sep.y + sep.height / 2);
        const center = dragCoord + base / 2;
        if (isPinned && center > sepCenter) return "unpin";
        if (!isPinned && center < sepCenter && !appId.startsWith("id:")) return "pin";
        return "";
    }

    onDraggingChanged:
    {
        view.dragActive = dragging;
        if (dragging) host.popupClose();
    }

    function along(mouse) { return dockItem.mapToItem(view, mouse.x, mouse.y)[horizontal ? "x" : "y"] }
    function cross(mouse)
    {
        const p = dockItem.mapToItem(view, mouse.x, mouse.y);

        if (side === Enums.EdgeTop) return p.y;
        if (side === Enums.EdgeBottom) return -p.y;
        if (side === Enums.EdgeLeft) return p.x;
        return -p.x;
    }

    onPressed: mouse =>
    {
        if (mouse.button !== Qt.LeftButton) return;
        grabCoord = horizontal ? mouse.x : mouse.y;
        pressCoord = along(mouse);
        pressCross = cross(mouse);
        crossOffset = 0;
        moved = false;
    }

    onPositionChanged: mouse =>
    {
        if (!(pressedButtons & Qt.LeftButton)) return;

        const mc = along(mouse);
        crossOffset = cross(mouse) - pressCross;

        if (!dragging && (Math.abs(mc - pressCoord) > 6 || Math.abs(crossOffset) > 10))
        {
            view.dragMouseCoord = mc;
            moved = true;
            dragging = true;
        }
        if (!dragging) return;

        view.dragMouseCoord = mc;

        const maxSz = horizontal ? view.width : view.height;
        const center = Math.max(0, Math.min(maxSz - 1, dragCoord + base / 2));
        const target = horizontal ? view.indexAt(center, base / 2) : view.indexAt(base / 2, center);
        if (target >= 0 && target !== index && dropAction === "") ServiceDock.move(index, target);
    }

    onReleased:
    {
        if (dragging)
        {
            const action = dropAction;
            dragging = false;
            if (action === "unpin") ServiceDock.unpin(appId);
            else if (action === "pin") ServiceDock.pinAt(appId, host.pinnedBefore(dragCoord + base / 2));
        }
    }
    onCanceled: dragging = false

    onClicked: mouse =>
    {
        if (moved) { moved = false; return; }

        if (mouse.button === Qt.RightButton) { host.menuOpen(dockItem); return; }

        host.popupClose();
        if (mouse.button === Qt.LeftButton) ServiceDock.activateApp(modelData);
        else if (mouse.button === Qt.MiddleButton) ServiceApplications.launch(appId);
    }

    Item
    {
        id: visual

        width: dockItem.width
        height: dockItem.height

        readonly property real crossHint: dockItem.dragging ? Math.max(-12, Math.min(24, dockItem.crossOffset * 0.35)) : 0

        x: (dockItem.horizontal && dockItem.dragging ? dockItem.dragCoord - dockItem.parent.x : 0)
            + (dockItem.horizontal ? 0 : (dockItem.side === Enums.EdgeLeft ? crossHint : -crossHint))
        y: (!dockItem.horizontal && dockItem.dragging ? dockItem.dragCoord - dockItem.parent.y : 0)
            + (dockItem.horizontal ? (dockItem.side === Enums.EdgeTop ? crossHint : -crossHint) : 0)

        Glide on x { enabled: !dockItem.dragging && Config.animationsEnabled }
        Glide on y { enabled: !dockItem.dragging && Config.animationsEnabled }

        property real lift: 0

        SequentialAnimation
        {
            running: activity.active && Config.animationsEnabled && (dockItem.launching || dockItem.isUrgent)
            loops: Animation.Infinite
            onRunningChanged: if (!running) visual.lift = 0

            NumberAnimation { target: visual; property: "lift"; to: dockItem.base * 0.32; duration: 260; easing.type: Easing.OutQuad }
            NumberAnimation { target: visual; property: "lift"; to: 0; duration: 300; easing.type: Easing.OutBounce }

            PauseAnimation { duration: dockItem.isUrgent && !dockItem.launching ? 1400 : 120 }
        }

        Item
        {
            id: tile

            width: dockItem.base
            height: dockItem.base

            readonly property real hoverShift: dockItem.containsMouse && !dockItem.dragging ? 10 : 0
            property real shift: hoverShift
            Glide on shift {}

            readonly property real out: shift + visual.lift
            x: dockItem.horizontal ? 0 : (dockItem.side === Enums.EdgeRight ? -out : out)
            y: dockItem.horizontal ? (dockItem.side === Enums.EdgeBottom ? -out : out) : 0

            scale: dockItem.dragging ? 1.15 : dockItem.pressed ? 1.1 : dockItem.containsMouse ? dockItem.host.zoomScale : 1
            transformOrigin: dockItem.side === Enums.EdgeTop ? Item.Top : dockItem.side === Enums.EdgeBottom ? Item.Bottom : dockItem.side === Enums.EdgeLeft ? Item.Left : Item.Right
            Spring on scale {}

            opacity: dockItem.dropAction === "unpin" ? 0.45 : 1
            Smooth on opacity {}

            Image
            {
                anchors.centerIn: parent
                width: Math.round(dockItem.base * 0.86)
                height: width
                readonly property int pixels: Math.ceil(dockItem.base * 1.2 * 0.86 * Screen.devicePixelRatio)
                sourceSize.width: pixels
                sourceSize.height: pixels
                source: ServiceApplications.iconFor(dockItem.appId)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
                opacity: dockItem.isRunning || dockItem.launching ? 1 : 0.7
            }

            Rectangle
            {
                visible: opacity > 0
                opacity: dockItem.badge > 0 ? 1 : 0
                scale: dockItem.badge > 0 ? 1 : 0.5
                Smooth on opacity { duration: 160 }
                Behavior on scale { enabled: Config.animationsEnabled; NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                anchors { top: parent.top; right: parent.right; topMargin: -2; rightMargin: -2 }
                height: Math.round(Math.max(16, parent.height * 0.36))
                width: Math.max(height, badgeText.implicitWidth + 8)
                radius: height / 2
                color: Theme.colorCritical
                border.width: 2
                border.color: Theme.colorSolid

                Text
                {
                    id: badgeText
                    anchors.centerIn: parent
                    text: dockItem.badge > 9 ? "9+" : String(Math.max(1, dockItem.badge))
                    color: Theme.onCritical
                    font.family: Theme.fontText
                    font.pixelSize: Math.round(parent.height * 0.6)
                    font.weight: Font.DemiBold
                }
            }

            Rectangle
            {
                visible: opacity > 0
                opacity: dockItem.dropAction !== "" ? 1 : 0
                Smooth on opacity {}

                anchors.horizontalCenter: parent.horizontalCenter
                y: dockItem.side === Enums.EdgeTop ? parent.height + 6 : -height - 6
                width: hintRow.implicitWidth + 14
                height: 22
                radius: 11
                color: Theme.colorSolid
                border.width: 1
                border.color: Theme.colorLine

                Row
                {
                    id: hintRow
                    anchors.centerIn: parent
                    spacing: 4

                    ShellIcon { anchors.verticalCenter: parent.verticalCenter; icon: dockItem.dropAction === "pin" ? Icon.pin : Icon.unpin; size: 12 }
                    ShellText { anchors.verticalCenter: parent.verticalCenter; label: dockItem.dropAction === "pin" ? Tr.tr("dock.pin") : Tr.tr("common.unpin"); size: 11; color: Theme.text1 }
                }
            }
        }

        Grid
        {
            id: indicator

            readonly property int dots: dockItem.isRunning ? Math.min(Math.max(dockItem.windowCount, 1), 3) : 0
            readonly property int activeDot: dockItem.isFocused ? Math.min(Math.max(dockItem.focusedIndex, 0), dots - 1) : -1

            rows: dockItem.horizontal ? 1 : -1
            columns: dockItem.horizontal ? -1 : 1
            spacing: 3

            readonly property real edgeGap: Math.round(Theme.dockPadding / 2) - 1
            x: dockItem.horizontal ? Math.round((dockItem.width - width) / 2)
                : (dockItem.side === Enums.EdgeLeft ? -edgeGap - width / 2 : dockItem.base + edgeGap - width / 2)
            y: dockItem.horizontal ? (dockItem.side === Enums.EdgeTop ? -edgeGap - height / 2 : dockItem.base + edgeGap - height / 2)
                : Math.round((dockItem.height - height) / 2)

            Repeater
            {
                model: indicator.dots

                Rectangle
                {
                    required property int index

                    readonly property bool active: index === indicator.activeDot
                    readonly property real along: active ? 12 : 4

                    width:  dockItem.horizontal ? along : 4
                    height: dockItem.horizontal ? 4 : along
                    radius: 2

                    color: dockItem.isUrgent ? Theme.colorAttention : active ? Theme.colorAccent : Theme.text3

                    Glide on width {}
                    Glide on height {}
                    Tint on color { duration: 160 }
                }
            }
        }
    }
}
