import QtQuick

import ".."
import "../../core"
import "../../services"

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
    implicitHeight: column.implicitHeight
    height: implicitHeight * collapse
    clip: collapse < 1

    function dismissAll(close)
    {
        if (leaving.running || !model) return;
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
    Component.onCompleted: if (entering) entrance.start()

    SequentialAnimation
    {
        id: entrance

        PropertyAction { target: column; property: "opacity"; value: 0 }
        PropertyAction { target: notificationGroup; property: "rise"; value: 18 }
        PauseAnimation { duration: 60 + Math.min(6, notificationGroup.order) * 45 }
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
        spacing: 2
        transform: Translate { y: notificationGroup.rise }

        Item
        {
            width: parent.width
            height: 24

            HoverHandler { id: headerHover }

            ShellText
            {
                id: name
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                width: Math.min(implicitWidth, parent.width - 120)
                label: notificationGroup.model ? notificationGroup.model.name : ""
                size: 11
                color: Theme.text3
                font.weight: Font.DemiBold
            }

            Rectangle
            {
                visible: notificationGroup.total > 1
                anchors { left: name.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                width: Math.max(18, countText.implicitWidth + 10)
                height: 16
                radius: 8
                color: Theme.colorField

                Glide on width {}

                ShellText { id: countText; anchors.centerIn: parent; label: String(notificationGroup.total); size: 10; color: Theme.text2 }
            }

            Row
            {
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                spacing: 2

                HeaderButton
                {
                    visible: notificationGroup.total > 1
                    icon: Icon.chevronDown
                    iconRotation: notificationGroup.expanded ? 180 : 0
                    onClicked: notificationGroup.requestToggle()
                }
                HeaderButton
                {
                    icon: Icon.close
                    shown: headerHover.hovered
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

        Item
        {
            visible: !notificationGroup.expanded && notificationGroup.total > 1
            width: parent.width
            height: 22

            ShellText
            {
                anchors { left: parent.left; leftMargin: 54; verticalCenter: parent.verticalCenter }
                label: Tr.tr("notifications.more").arg(notificationGroup.total - 1)
                size: 11
                color: moreArea.containsMouse ? Theme.text1 : Theme.text4
                Tint on color {}
            }
            MouseArea
            {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notificationGroup.requestToggle()
            }
        }
    }

    component HeaderButton: Rectangle
    {
        id: button
        property string icon: ""
        property real   iconRotation: 0
        property bool   shown: true
        signal clicked()

        width: 20
        height: 20
        radius: 10
        color: buttonArea.pressed ? Theme.colorPressed : buttonArea.containsMouse ? Theme.colorHoverStrong : "transparent"
        opacity: shown || buttonArea.containsMouse ? 1 : 0
        scale: buttonArea.pressed ? 0.9 : buttonArea.containsMouse ? 1.1 : 1
        Smooth on opacity {}
        Spring on scale {}
        Tint on color {}

        ShellIcon
        {
            anchors.centerIn: parent
            icon: button.icon
            size: 10
            rotation: button.iconRotation
            Ease on rotation { duration: Theme.animationDurationControl }
        }

        MouseArea
        {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
