import QtQuick

import "../animations"
import "../core"
import "../services"

Item
{
    id: notificationGroup

    property var  model
    property bool expanded: false
    property real now: Date.now()

    property bool entering: false
    property int  order: 0

    signal toggle()
    signal activated()

    readonly property int total: model ? model.items.length : 0

    property bool justExpanded: false
    function requestToggle()
    {
        justExpanded = !expanded;
        settleExpand.restart();
        toggle();
    }
    Timer { id: settleExpand; interval: 500; onTriggered: notificationGroup.justExpanded = false }

    width: parent ? parent.width : 300
    property real collapse: 1
    property bool settled: false
    implicitHeight: column.implicitHeight
    height: implicitHeight * collapse
    clip: collapse < 1 || height + 0.5 < implicitHeight
    enabled: !leaving.running
    Glide on height { enabled: Config.animationsEnabled && notificationGroup.settled && !leaving.running; duration: Theme.animationDurationControl }

    property var pendingDismissal: []

    function dismissAll(close = true, direction = 0)
    {
        if (leaving.running || !model) return;
        entrance.stop();
        if (close) pendingDismissal = model.items.slice();
        leaving.destination = direction === 0 ? card.x : Math.sign(direction) * width;
        leaving.restart();
    }

    function finishDismissal()
    {
        const pending = pendingDismissal;
        pendingDismissal = [];
        if (pending.length > 0) Qt.callLater(() => pending.forEach(item => ServiceNotifications.dismiss(item)));
    }
    Component.onDestruction: finishDismissal()

    SequentialAnimation
    {
        id: leaving
        readonly property bool animated: Config.animationsEnabled
        property real destination: 0

        ParallelAnimation
        {
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: leaving.animated ? Theme.animationDurationClose : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate }
            NumberAnimation { target: card; property: "x"; to: leaving.destination; duration: leaving.animated ? Theme.animationDurationClose : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate }
        }
        NumberAnimation { target: notificationGroup; property: "collapse"; to: 0; duration: leaving.animated ? 240 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
        ScriptAction { script: notificationGroup.finishDismissal() }
    }

    property real rise: 0
    Component.onCompleted:
    {
        if (entering && Config.animationsEnabled) entrance.start();
        const group = notificationGroup;
        Qt.callLater(() => { if (group) group.settled = true; });
    }

    SequentialAnimation
    {
        id: entrance

        PropertyAction { target: card; property: "opacity"; value: 0 }
        PropertyAction { target: notificationGroup; property: "rise"; value: Config.animationsFluid ? 18 : 6 }
        PauseAnimation { duration: (Config.animationsFluid ? 35 : 0) + Math.max(0, Math.min(6, notificationGroup.order)) * (Config.animationsFluid ? 30 : 12) }
        ParallelAnimation
        {
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
            NumberAnimation { target: notificationGroup; property: "rise"; to: 0; duration: 440; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
        }
    }

    DragHandler
    {
        id: swipe
        parent: notificationGroup.expanded ? header : notificationGroup
        target: null
        acceptedButtons: Qt.LeftButton
        dragThreshold: 8
        yAxis.enabled: false

        onTranslationChanged: if (active) card.x = Math.max(-notificationGroup.width, Math.min(notificationGroup.width, translation.x))
        onGrabChanged: transition =>
        {
            if (transition === PointerDevice.UngrabExclusive)
            {
                if (Math.abs(card.x) > notificationGroup.width * 0.3) notificationGroup.dismissAll(true, card.x);
                else card.x = 0;
            }
            else if (transition === PointerDevice.CancelGrabExclusive && !leaving.running) card.x = 0;
        }
    }

    Item
    {
        id: card
        width: parent.width
        height: column.implicitHeight
        y: notificationGroup.rise
        Spring on x { enabled: Config.animationsEnabled && !swipe.active && !leaving.running }

        Rectangle
        {
            anchors.fill: parent
            radius: Theme.controlRadius
            color: Theme.controlColorBackground
        }

        Column
        {
            id: column
            width: parent.width
            spacing: 0

            Item
            {
                id: header
                width: parent.width
                height: 44
                NotificationIcon
                {
                    id: appIcon
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    n: notificationGroup.model && notificationGroup.total > 0 ? notificationGroup.model.items[0] : null
                    size: 24
                }
                ShellText
                {
                    id: name
                    anchors { left: appIcon.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    width: Math.max(0, Math.min(implicitWidth, dismissButton.x - x - (counter.visible ? counter.width + 6 : 0) - 4))
                    label: notificationGroup.model ? notificationGroup.model.name : ""
                    size: 12
                    color: Theme.text1
                    font.weight: Font.DemiBold
                }
                Rectangle
                {
                    id: counter
                    visible: notificationGroup.total > 1
                    anchors { left: name.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                    width: Math.max(18, countText.implicitWidth + 10)
                    height: 18
                    radius: 6
                    color: Theme.colorField
                    Glide on width {}
                    ShellText { id: countText; anchors.centerIn: parent; label: String(notificationGroup.total); size: 10; color: Theme.text3 }
                }
                Button
                {
                    id: dismissButton
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24; radius: 8
                    text: Tr.tr("notifications.clearGroup").arg(notificationGroup.model ? notificationGroup.model.name : "")
                    icon: Icon.close
                    iconSize: 10
                    iconOnly: true
                    color: "transparent"
                    onClicked: notificationGroup.dismissAll()
                }
            }

            Repeater
            {
                model: notificationGroup.model ? (notificationGroup.expanded ? notificationGroup.model.items : notificationGroup.model.items.slice(0, 1)) : []
                NotificationRow
                {
                    required property var modelData
                    required property int index
                    n: modelData
                    grouped: true
                    swipeToDismiss: notificationGroup.expanded
                    now: notificationGroup.now
                    entering: notificationGroup.justExpanded && index > 0
                    order: index - 1
                    onActivated: notificationGroup.activated()
                }
            }

            Item
            {
                visible: notificationGroup.total > 1
                width: parent.width
                height: 36
                Button
                {
                    objectName: "notificationGroupToggle"
                    anchors.centerIn: parent
                    height: 28
                    radius: 8
                    text: Tr.tr(notificationGroup.expanded ? "notifications.showLess" : "notifications.showMore")
                    textSize: 11
                    onClicked: notificationGroup.requestToggle()
                }
            }
        }
    }
}
