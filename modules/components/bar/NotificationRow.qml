import QtQuick
import Quickshell.Services.Notifications

import ".."
import "../../core"
import "../../services"

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
    property bool leaving: false

    width: parent ? parent.width : 300
    implicitHeight: content.implicitHeight + 20

    property real collapse: 1
    height: implicitHeight * collapse
    clip: collapse < 1

    function dismiss(direction)
    {
        if (leaving) return;
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
        onClicked: if (!drag.active && Math.abs(card.x) < 2 && notificationRow.n) { ServiceNotifications.activate(notificationRow.n); notificationRow.activated() }
    }

    Item
    {
        id: card

        width: notificationRow.width
        height: notificationRow.implicitHeight

        readonly property real fade: 1 - Math.min(1, Math.abs(x) / notificationRow.width) * 0.8
        transform: Translate { y: notificationRow.rise }

        scale: area.drag.active ? 1 : area.pressed ? 0.98 : area.containsMouse ? 1.015 : 1

        Spring on x { enabled: Config.animationsEnabled && !area.drag.active && !notificationRow.leaving }
        Spring on scale {}

        Rectangle
        {
            anchors.fill: parent
            radius: Theme.radiusMedium
            color: Theme.menuColorHover
            opacity: (area.containsMouse || area.drag.active ? 1 : 0) * card.fade

            Smooth on opacity {}
        }

        Rectangle
        {
            visible: notificationRow.critical
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 10; bottomMargin: 10 }
            width: 3
            radius: 1.5
            color: Theme.colorCritical
        }

        NotificationIcon
        {
            id: icon
            n: notificationRow.n
            size: 34
            opacity: card.fade
            anchors { left: parent.left; leftMargin: 10; top: parent.top; topMargin: 10 }
        }

        Column
        {
            id: content

            anchors
            {
                left: icon.right; leftMargin: 10
                right: parent.right; rightMargin: 10
                top: parent.top; topMargin: 10
            }
            spacing: 2
            opacity: card.fade

            Item
            {
                width: parent.width
                height: summary.implicitHeight

                ShellText
                {
                    id: summary
                    anchors { left: parent.left; right: side.left; rightMargin: 8 }
                    label: notificationRow.n ? (notificationRow.n.summary || notificationRow.n.appName || "") : ""
                    size: 13
                    color: Theme.text1
                    font.weight: Font.Medium
                }

                Item
                {
                    id: side
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: Math.max(time.implicitWidth, 20)
                    height: 20

                    ShellText
                    {
                        id: time
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        label: ServiceNotifications.age(notificationRow.n, notificationRow.now)
                        size: 10
                        color: Theme.text4
                        opacity: area.containsMouse ? 0 : 1
                        Smooth on opacity {}
                    }

                    Rectangle
                    {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 20
                        height: 20
                        radius: 10
                        scale: closeArea.pressed ? 0.9 : closeArea.containsMouse ? 1.1 : 1
                        Spring on scale {}
                        color: closeArea.pressed ? Theme.colorPressed : closeArea.containsMouse ? Theme.colorHoverStrong : "transparent"
                        opacity: area.containsMouse || closeArea.containsMouse ? 1 : 0
                        Smooth on opacity {}
                        Tint on color {}

                        ShellIcon { anchors.centerIn: parent; icon: Icon.close; size: 10 }

                        MouseArea
                        {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notificationRow.dismiss(1)
                        }
                    }
                }
            }

            ShellText
            {
                width: parent.width
                label: notificationRow.n ? (notificationRow.n.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() : ""
                size: 11
                color: Theme.text3
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            Flow
            {
                visible: notificationRow.actions.length > 0
                width: parent.width
                topPadding: 4
                spacing: 6

                Repeater
                {
                    model: notificationRow.actions

                    Rectangle
                    {
                        id: chip
                        required property var modelData

                        width: label.implicitWidth + 20
                        height: 24
                        radius: 12
                        scale: chipArea.pressed ? 0.95 : chipArea.containsMouse ? 1.04 : 1
                        Spring on scale {}
                        color: chipArea.pressed ? Theme.colorPressed : chipArea.containsMouse ? Theme.colorHoverStrong : Theme.colorField
                        Tint on color {}

                        ShellText { id: label; anchors.centerIn: parent; label: chip.modelData.text; size: 11; color: Theme.text1 }

                        MouseArea
                        {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: chip.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
