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

    function dismissAll(close)
    {
        if (leaving.running || !model) return;
        entrance.stop();
        leaving.close = close !== false;
        leaving.restart();
    }

    SequentialAnimation
    {
        id: leaving
        readonly property bool animated: Config.animationsEnabled
        property bool close: true

        NumberAnimation { target: column; property: "opacity"; to: 0; duration: leaving.animated ? Theme.animationDurationClose : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate }
        NumberAnimation { target: notificationGroup; property: "collapse"; to: 0; duration: leaving.animated ? 240 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
        ScriptAction { script: if (leaving.close && notificationGroup.model) ServiceNotifications.dismissGroup(notificationGroup.model.key) }
    }

    property real rise: 0
    Component.onCompleted:
    {
        if (entering && Config.animationsEnabled) entrance.start();
        Qt.callLater(() => settled = true);
    }

    SequentialAnimation
    {
        id: entrance

        PropertyAction { target: column; property: "opacity"; value: 0 }
        PropertyAction { target: notificationGroup; property: "rise"; value: Config.animationsFluid ? 18 : 6 }
        PauseAnimation { duration: (Config.animationsFluid ? 35 : 0) + Math.max(0, Math.min(6, notificationGroup.order)) * (Config.animationsFluid ? 30 : 12) }
        ParallelAnimation
        {
            NumberAnimation { target: column; property: "opacity"; to: 1; duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
            NumberAnimation { target: notificationGroup; property: "rise"; to: 0; duration: 440; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
        }
    }

    Column
    {
        id: column

        width: parent.width
        spacing: 4
        transform: Translate { y: notificationGroup.rise }

        Item
        {
            width: parent.width
            height: 32

            ShellText
            {
                id: name
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                width: Math.max(0, Math.min(implicitWidth, parent.width - controls.width - (notificationGroup.total > 1 ? counter.width + 6 : 0) - 28))
                label: notificationGroup.model ? notificationGroup.model.name : ""
                size: 12
                color: Theme.text2
                font.weight: Font.Medium
            }

            Rectangle
            {
                id: counter
                visible: notificationGroup.total > 1
                anchors { left: name.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                width: Math.max(18, countText.implicitWidth + 10)
                height: 18
                radius: 9
                color: Theme.colorField

                Glide on width {}

                ShellText { id: countText; anchors.centerIn: parent; label: String(notificationGroup.total); size: 10; color: Theme.text2 }
            }

            Row
            {
                id: controls
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                spacing: 4

                ActionButton
                {
                    visible: notificationGroup.total > 1
                    text: Tr.tr(notificationGroup.expanded ? "notifications.collapse" : "notifications.expand")
                    icon: Icon.chevronDown
                    iconOnly: true
                    rotation: notificationGroup.expanded ? 180 : 0
                    Ease on rotation { duration: Theme.animationDurationControl }
                    onClicked: notificationGroup.requestToggle()
                }
                ActionButton
                {
                    text: Tr.tr("notifications.clearGroup").arg(notificationGroup.model ? notificationGroup.model.name : "")
                    icon: Icon.close
                    iconOnly: true
                    onClicked: notificationGroup.dismissAll()
                }
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
                now: notificationGroup.now
                entering: notificationGroup.justExpanded && index > 0
                order: index - 1
                onActivated: notificationGroup.activated()
            }
        }

        ActionButton
        {
            visible: !notificationGroup.expanded && notificationGroup.total > 1
            width: parent.width
            height: 28
            text: Tr.tr("notifications.more").arg(notificationGroup.total - 1)
            icon: Icon.chevronDown
            onClicked: notificationGroup.requestToggle()
        }
    }
}
