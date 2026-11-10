import QtQuick
import Quickshell.Services.Notifications

import "../animations"
import "../core"
import "../services"

Item
{
    id: notificationRow

    property var  n
    property real now: Date.now()

    property bool entering: false
    property int  order: 0

    signal activated()

    readonly property var  actions: n ? (n.actions || []).filter(a => a.identifier !== "default" && a.text !== "") : []
    readonly property bool critical: n ? n.urgency === NotificationUrgency.Critical : false
    readonly property bool hovered: hover.hovered || activeFocus
    property bool leaving: false

    width: parent ? parent.width : 300
    implicitHeight: Math.max(56, content.implicitHeight + 24)
    activeFocusOnTab: !leaving
    enabled: !leaving
    HoverHandler { id: hover }

    function activate()
    {
        if (!n || leaving) return;
        ServiceNotifications.activate(n);
        activated();
    }
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) activate(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) activate(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) activate(); event.accepted = true }
    Keys.onDeletePressed: dismiss(1)

    Accessible.role: Accessible.Button
    Accessible.name: n ? (n.summary || n.appName || "") : ""
    Accessible.onPressAction: activate()

    property real collapse: 1
    height: implicitHeight * collapse
    clip: collapse < 1

    function dismiss(direction)
    {
        if (leaving) return;
        entrance.stop();
        leaving = true;
        throwAway.to = (direction < 0 ? -1 : 1) * notificationRow.width;
        throwAway.restart();
    }

    SequentialAnimation
    {
        id: throwAway
        property real to: 0
        readonly property bool animated: Config.animationsEnabled

        NumberAnimation
        {
            target: card; property: "x"; to: throwAway.to
            duration: throwAway.animated ? Theme.animationDurationClose : 0
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate
        }
        NumberAnimation
        {
            target: notificationRow; property: "collapse"; to: 0
            duration: throwAway.animated ? 220 : 0
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized
        }
        ScriptAction { script: if (notificationRow.n) ServiceNotifications.dismiss(notificationRow.n) }
    }

    property real rise: 0
    Component.onCompleted: if (entering && Config.animationsEnabled) entrance.start()

    SequentialAnimation
    {
        id: entrance

        PropertyAction { target: card; property: "opacity"; value: 0 }
        PropertyAction { target: notificationRow; property: "rise"; value: Config.animationsFluid ? 14 : 6 }
        PauseAnimation { duration: Math.max(0, Math.min(6, notificationRow.order)) * 35 }
        ParallelAnimation
        {
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
            NumberAnimation { target: notificationRow; property: "rise"; to: 0; duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        drag.target: card
        drag.axis: Drag.XAxis
        drag.threshold: 8
        drag.minimumX: -notificationRow.width
        drag.maximumX: notificationRow.width

        onReleased:
        {
            if (notificationRow.leaving) return;
            if (Math.abs(card.x) > notificationRow.width * 0.3) notificationRow.dismiss(card.x);
            else card.x = 0;
        }
        onCanceled: if (!notificationRow.leaving) card.x = 0
        onClicked: if (!drag.active && Math.abs(card.x) < 2) notificationRow.activate()
    }

    Item
    {
        id: card

        width: notificationRow.width
        height: notificationRow.implicitHeight

        readonly property real fade: 1 - Math.min(1, Math.abs(x) / notificationRow.width) * 0.8
        transform: Translate { y: notificationRow.rise }

        scale: area.drag.active ? 1 : area.pressed ? 0.98 : notificationRow.hovered && Config.animationsFluid ? 1.01 : 1

        Spring on x { enabled: Config.animationsEnabled && !area.drag.active && !notificationRow.leaving }
        Spring on scale {}

        Rectangle
        {
            anchors.fill: parent
            radius: notificationRow.hovered && Config.animationsFluid ? 14 : 18
            color: notificationRow.critical ? Qt.tint(Theme.colorField, Qt.rgba(Theme.colorCritical.r, Theme.colorCritical.g, Theme.colorCritical.b, 0.08)) : Theme.colorField
            opacity: card.fade
            Tint on color {}
            Glide on radius { duration: Theme.animationDurationControl }

            Rectangle
            {
                anchors.fill: parent
                radius: parent.radius
                color: area.pressed ? Theme.colorPressed : Theme.colorHoverStrong
                opacity: notificationRow.hovered || area.drag.active ? 1 : 0
                Smooth on opacity {}
                Tint on color {}
            }
        }

        Rectangle
        {
            visible: notificationRow.critical
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 10; bottomMargin: 10 }
            width: 3
            radius: 1.5
            color: Theme.colorCritical
            opacity: card.fade
        }

        NotificationIcon
        {
            id: icon
            n: notificationRow.n
            size: 32
            opacity: card.fade
            anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 12 }
        }

        Column
        {
            id: content

            anchors
            {
                left: icon.right; leftMargin: 10
                right: parent.right; rightMargin: 12
                top: parent.top; topMargin: 12
            }
            spacing: 2
            opacity: card.fade

            Item
            {
                width: parent.width
                height: Math.max(24, summary.implicitHeight)

                ShellText
                {
                    id: summary
                    anchors { left: parent.left; right: side.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    label: notificationRow.n ? (notificationRow.n.summary || notificationRow.n.appName || "") : ""
                    size: 12
                    color: Theme.text1
                    font.weight: Font.Medium
                }

                Item
                {
                    id: side
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: Math.max(time.implicitWidth, 24)
                    height: 24

                    ShellText
                    {
                        id: time
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        label: ServiceNotifications.age(notificationRow.n, notificationRow.now)
                        size: 10
                        color: Theme.text4
                        opacity: notificationRow.hovered || close.hovered ? 0 : 1
                        Smooth on opacity {}
                    }

                    ActionButton
                    {
                        id: close
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 24
                        height: 24
                        text: Tr.tr("common.close")
                        icon: Icon.close
                        iconSize: 10
                        iconOnly: true
                        opacity: notificationRow.hovered || hovered ? 1 : 0
                        Smooth on opacity {}
                        onClicked: notificationRow.dismiss(1)
                    }
                }
            }

            ShellText
            {
                width: parent.width
                label: notificationRow.n ? (notificationRow.n.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() : ""
                size: 11
                color: Theme.text2
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }

            Flow
            {
                id: buttons
                visible: notificationRow.actions.length > 0
                width: parent.width
                topPadding: 4
                spacing: 6

                Repeater
                {
                    model: notificationRow.actions

                    ActionButton
                    {
                        required property var modelData
                        maximumWidth: buttons.width
                        text: modelData.text
                        height: 28
                        radius: 12
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }
}
