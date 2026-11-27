pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../animations"
import "../core"
import "../services"

Item
{
    id: group
    objectName: "notificationStack"

    required property var model
    property bool expanded: false
    property real now: Date.now()
    signal activated()

    readonly property var notifications: model?.items ?? []
    readonly property int total: notifications.length
    readonly property int layers: expanded ? 0 : Math.min(2, Math.max(0, total - 1))
    property var pendingDismissals: []
    property real collapse: 1

    implicitHeight: pile.implicitHeight
    height: implicitHeight * collapse
    visible: total > 0 && collapse > 0
    enabled: !leaving.running
    clip: true
    Glide on height { enabled: Config.animationsEnabled && !leaving.running; duration: Theme.animationDurationControl }

    function dismissAll(direction = 1)
    {
        if (leaving.running || total === 0) return;
        pendingDismissals = notifications.slice();
        leaving.destination = Math.sign(direction) * width;
        leaving.start();
    }

    function finishDismissal(restore)
    {
        const pending = pendingDismissals;
        pendingDismissals = [];
        if (pending.length > 0) Qt.callLater(() => pending.forEach(notification => ServiceNotifications.dismiss(notification)));
        if (restore && notifications.some(notification => !pending.includes(notification)))
        {
            pile.x = 0;
            pile.opacity = 1;
            collapse = 1;
        }
    }
    Component.onDestruction: finishDismissal(false)

    SequentialAnimation
    {
        id: leaving
        property real destination: 0

        ParallelAnimation
        {
            NumberAnimation { target: pile; property: "opacity"; to: 0; duration: Theme.animationDurationClose; easing.type: Easing.InCubic }
            NumberAnimation { target: pile; property: "x"; to: leaving.destination; duration: Theme.animationDurationClose; easing.type: Easing.InCubic }
        }
        NumberAnimation { target: group; property: "collapse"; to: 0; duration: Theme.animationDuration(160); easing.type: Easing.OutCubic }
        ScriptAction { script: group.finishDismissal(true) }
    }

    Column
    {
        id: pile
        width: parent.width
        spacing: 4
        Glide on x { enabled: Config.animationsEnabled && !swipe.active && !leaving.running; duration: Theme.animationDurationControl }

        Item
        {
            width: parent.width
            height: 32

            NotificationIcon
            {
                id: app
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                n: group.notifications[0] ?? null
                size: 22
            }
            ShellText
            {
                anchors { left: app.right; leftMargin: 7; right: count.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                label: group.model?.name ?? ""
                size: 12
                font.weight: Font.DemiBold
                color: Theme.text1
            }
            Rectangle
            {
                id: count
                anchors { right: dismiss.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                width: group.total > 1 ? Math.max(18, number.implicitWidth + 9) : 0
                height: 18
                radius: height / 2
                visible: width > 0
                color: Theme.colorField
                ShellText { id: number; anchors.centerIn: parent; label: String(group.total); size: 10; color: Theme.text3 }
            }
            Button
            {
                id: dismiss
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 24; height: 24; radius: 8
                text: Tr.tr("notifications.clearGroup").arg(group.model?.name ?? "")
                icon: Icon.close
                iconSize: 10
                iconOnly: true
                color: "transparent"
                onClicked: group.dismissAll()
            }
        }

        Item
        {
            width: parent.width
            height: cards.implicitHeight + group.layers * 5

            Repeater
            {
                model: group.layers

                Rectangle
                {
                    required property int index
                    readonly property int depth: group.layers - index
                    objectName: "notificationStackLayer"
                    x: depth * 6
                    y: depth * 5
                    width: Math.max(0, parent.width - 2 * x)
                    height: cards.implicitHeight
                    radius: Theme.controlRadius
                    color: Theme.controlColorBackground
                    border.color: Theme.controlColorBorder
                    border.width: 1
                }
            }

            Column
            {
                id: cards
                width: parent.width
                spacing: 5

                Repeater
                {
                    model: ScriptModel
                    {
                        values: group.expanded ? group.notifications : group.notifications.slice(0, 1)
                        objectProp: "id"
                    }

                    NotificationRow
                    {
                        required property var modelData
                        n: modelData
                        grouped: true
                        now: group.now
                        onActivated: group.activated()
                    }
                }
            }
        }

        Button
        {
            objectName: "notificationGroupToggle"
            visible: group.total > 1
            anchors.horizontalCenter: parent.horizontalCenter
            height: 28
            radius: height / 2
            text: Tr.tr(group.expanded ? "notifications.showLess" : "notifications.showMore")
            textSize: 11
            onClicked: group.expanded = !group.expanded
        }
    }

    Item
    {
        objectName: "notificationGroupSwipeArea"
        width: parent.width
        height: 32

        DragHandler
        {
            id: swipe
            target: null
            acceptedButtons: Qt.LeftButton
            dragThreshold: 8
            yAxis.enabled: false

            onTranslationChanged: if (active) pile.x = Math.max(-group.width, Math.min(group.width, translation.x))
            onGrabChanged: transition =>
            {
                if (transition === PointerDevice.UngrabExclusive)
                {
                    if (Math.abs(pile.x) > group.width * 0.3) group.dismissAll(pile.x);
                    else pile.x = 0;
                }
                else if (transition === PointerDevice.CancelGrabExclusive && !leaving.running) pile.x = 0;
            }
        }
    }
}
