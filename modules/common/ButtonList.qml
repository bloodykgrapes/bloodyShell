import QtQuick
import "." as Common

import "../animations"
import "../core"

Common.InteractiveControl
{
    id: buttonList

    property string icon: ""
    property string text: ""
    property string subtitle: ""
    property string trailing: ""
    property string trailingIcon: ""
    property bool   selected: false
    property bool   busy: false
    property bool   prominent: false
    property bool   filled: false
    property bool   interactive: true
    property bool   danger: false
    property bool   persistentActions: false
    property real   level: -1
    property Component leading: null
    property real cornerRadius: Theme.menuControlRadius
    property color surfaceColor: Theme.menuControlBackground

    default property alias actions: actionsRow.data
    readonly property bool hasActions: actionsRow.children.some(child => child.visible)
    readonly property bool highlighted: enabled && (hovered || visualFocus)
    readonly property bool showActions: hasActions && (persistentActions || prominent || highlighted)
    readonly property MenuList view: ListView.view as MenuList

    RenderActivity { id: activity; target: buttonList }

    signal clicked()
    activeFocusOnTab: enabled && interactive && !busy
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat && interactive && !busy) clicked(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat && interactive && !busy) clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat && interactive && !busy) clicked(); event.accepted = true }

    Accessible.role: interactive ? Accessible.Button : Accessible.StaticText
    Accessible.name: text + (subtitle !== "" ? ", " + subtitle : "")
    Accessible.onPressAction: if (enabled && interactive && !busy) clicked()

    width: view ? view.rowWidth : parent ? parent.width : 200
    height: implicitHeight
    implicitHeight: Math.max(prominent ? 56 : filled ? (subtitle !== "" || level >= 0 ? 48 : 40) : subtitle !== "" || level >= 0 ? 46 : 36, labels.implicitHeight + 16)

    scale: area.pressed ? 0.98 : interactive && buttonList.highlighted ? (filled ? Config.animationsFluid ? 1.01 : 1 : 1.025) : 1
    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: buttonList.cornerRadius
        color: buttonList.selected ? Theme.menuControlSelected
            : buttonList.prominent || buttonList.filled ? buttonList.surfaceColor
            : buttonList.danger ? Theme.criticalAlpha(0.12) : buttonList.visualFocus ? Theme.colorHoverStrong : Theme.menuColorHover
        opacity: buttonList.filled || buttonList.prominent || buttonList.selected || buttonList.highlighted ? 1 : 0

        Smooth on opacity {}
        Tint on color {}
        Glide on radius { duration: Theme.animationDurationControl }

        Rectangle
        {
            anchors.fill: parent
            radius: parent.radius
            color: buttonList.danger ? Theme.criticalAlpha(0.22) : area.pressed ? Theme.colorPressed : Theme.colorHoverStrong
            opacity: buttonList.interactive && (area.pressed || (buttonList.filled && buttonList.highlighted)) ? 1 : 0
            Smooth on opacity {}
            Tint on color {}
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: buttonList.interactive && !buttonList.busy
        cursorShape: Qt.PointingHandCursor
        onPressed: buttonList.focusFor(Qt.MouseFocusReason)
        onClicked: buttonList.clicked()
    }

    Item
    {
        id: body
        anchors.fill: parent

        Item
        {
            id: glyph
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            visible: buttonList.leading !== null || buttonList.icon !== ""
            width: buttonList.prominent ? 18 : 16
            height: width

            ShellIcon
            {
                visible: buttonList.leading === null && icon !== ""
                icon: buttonList.icon
                size: glyph.width
                opacity: buttonList.selected ? 1 : 0.8
                zoom: 1.05
            }
            Loader { anchors.fill: parent; sourceComponent: buttonList.leading }
        }

        Column
        {
            id: labels
            anchors
            {
                left: glyph.visible ? glyph.right : parent.left
                leftMargin: glyph.visible ? 10 : 12
                right: tail.left
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            spacing: 1

            ShellText
            {
                width: parent.width
                label: buttonList.text
                size: buttonList.prominent ? 13 : 12
                font.weight: buttonList.prominent || buttonList.filled ? Font.Medium : Font.Normal
                color: buttonList.danger ? Theme.colorCritical : buttonList.selected || buttonList.filled ? Theme.text1 : Theme.text2
                Tint on color {}
            }

            Row
            {
                width: parent.width
                spacing: 6
                visible: buttonList.subtitle !== "" || buttonList.level >= 0

                Rectangle
                {
                    visible: buttonList.level >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 6
                    radius: 3
                    color: Theme.colorField

                    Rectangle
                    {
                        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, buttonList.level)))
                        height: parent.height
                        radius: parent.radius
                        color: buttonList.level <= 0.15 ? Theme.colorCritical : buttonList.level <= 0.3 ? Theme.colorWarning : Theme.colorAccent
                        Glide on width {}
                        Tint on color {}
                    }
                }
                ShellText
                {
                    width: parent.width - (buttonList.level >= 0 ? 28 : 0)
                    label: buttonList.subtitle
                    size: 10
                    color: Theme.text3
                }
            }
        }

        Item
        {
            id: tail
            anchors { right: parent.right; rightMargin: buttonList.showActions ? 6 : 10; verticalCenter: parent.verticalCenter }
            width: buttonList.showActions ? actionsRow.implicitWidth : marks.implicitWidth
            height: 24
            Glide on width {}

            Row
            {
                id: marks
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 6
                opacity: buttonList.showActions ? 0 : 1
                Smooth on opacity {}

                ShellText
                {
                    anchors.verticalCenter: parent.verticalCenter
                    label: buttonList.trailing
                    size: 11
                    color: Theme.text3
                }
                ShellIcon
                {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: buttonList.selected ? Icon.check : buttonList.trailingIcon
                    size: 14
                    opacity: buttonList.selected ? 1 : 0.6
                }
            }

            Row
            {
                id: actionsRow
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 2
                enabled: buttonList.showActions
                opacity: buttonList.showActions ? 1 : 0
                Smooth on opacity {}

            }
        }

        SequentialAnimation on opacity
        {
            running: buttonList.busy && Config.animationsEnabled && activity.active
            loops: Animation.Infinite
            onRunningChanged: if (!running) body.opacity = 1
            NumberAnimation { to: 0.45; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1;    duration: 500; easing.type: Easing.InOutSine }
        }
    }
}
