import QtQuick
import "." as Common

import "../animations"
import "../core"

Common.InteractiveControl
{
    id: menuRow


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
    property real   level: -1

    default property alias actions: actionsRow.data
    readonly property bool hasActions: actionsRow.children.some(child => child.visible)
    readonly property bool highlighted: enabled && (hovered || visualFocus)
    readonly property bool showActions: hasActions && (prominent || highlighted)
    readonly property MenuList view: ListView.view as MenuList

    RenderActivity { id: activity; target: menuRow }

    signal clicked()
    activeFocusOnTab: enabled && interactive && !busy
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat && interactive && !busy) clicked(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat && interactive && !busy) clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat && interactive && !busy) clicked(); event.accepted = true }

    Accessible.role: interactive ? Accessible.Button : Accessible.StaticText
    Accessible.name: text + (subtitle !== "" ? ", " + subtitle : "")
    Accessible.onPressAction: if (enabled && interactive && !busy) clicked()

    width: view ? view.rowWidth : parent ? parent.width : 200
    height: Math.max(prominent ? (filled ? 68 : 58) : filled ? (subtitle !== "" || level >= 0 ? 48 : 40) : subtitle !== "" || level >= 0 ? 46 : 36, labels.implicitHeight + 16)

    scale: area.pressed ? 0.98 : interactive && menuRow.highlighted ? (filled ? Config.animationsFluid ? 1.01 : 1 : 1.025) : 1
    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: menuRow.filled ? (menuRow.highlighted && Config.animationsFluid ? (menuRow.prominent ? 14 : 12) : (menuRow.prominent ? 18 : 14)) : menuRow.prominent ? Theme.radiusLarge : Theme.radiusMedium
        color: menuRow.selected ? Theme.colorCurrent : menuRow.prominent || menuRow.filled ? Theme.colorField : Theme.menuColorHover
        opacity: menuRow.filled || menuRow.prominent || menuRow.selected || menuRow.highlighted ? 1 : 0

        Smooth on opacity {}
        Tint on color {}
        Glide on radius { duration: Theme.animationDurationControl }

        Rectangle
        {
            anchors.fill: parent
            radius: parent.radius
            color: area.pressed ? Theme.colorPressed : Theme.colorHoverStrong
            opacity: menuRow.filled && menuRow.interactive && menuRow.highlighted ? 1 : 0
            Smooth on opacity {}
            Tint on color {}
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: menuRow.interactive && !menuRow.busy
        cursorShape: Qt.PointingHandCursor
        onPressed: menuRow.focusFor(Qt.MouseFocusReason)
        onClicked: menuRow.clicked()
    }

    Item
    {
        id: body
        anchors.fill: parent

        Rectangle
        {
            anchors.centerIn: glyph
            width: menuRow.filled ? (menuRow.prominent ? 40 : 30) : 36
            height: width
            radius: menuRow.filled ? (menuRow.prominent ? 13 : 11) : 18
            visible: menuRow.prominent || menuRow.filled
            color: menuRow.selected ? Theme.colorChosen : Theme.colorHoverStrong
            Tint on color {}
        }

        ShellIcon
        {
            id: glyph
            anchors { left: parent.left; leftMargin: menuRow.filled ? (menuRow.prominent ? 23 : 21) : menuRow.prominent ? 19 : 10; verticalCenter: parent.verticalCenter }
            icon: menuRow.icon
            size: menuRow.prominent ? 18 : 16
            opacity: menuRow.selected ? 1 : 0.8
            zoom: 1.05
        }

        Column
        {
            id: labels
            anchors
            {
                left: glyph.visible ? glyph.right : parent.left
                leftMargin: menuRow.filled ? (menuRow.prominent ? 23 : 19) : menuRow.prominent ? 19 : 10
                right: tail.left
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            spacing: 1

            ShellText
            {
                width: parent.width
                label: menuRow.text
                size: menuRow.prominent ? 13 : 12
                font.weight: menuRow.prominent || menuRow.filled ? Font.Medium : Font.Normal
                color: menuRow.selected || menuRow.filled ? Theme.text1 : Theme.text2
                Tint on color {}
            }

            Row
            {
                width: parent.width
                spacing: 6
                visible: menuRow.subtitle !== "" || menuRow.level >= 0

                Rectangle
                {
                    visible: menuRow.level >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 6
                    radius: 3
                    color: Theme.colorField

                    Rectangle
                    {
                        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, menuRow.level)))
                        height: parent.height
                        radius: parent.radius
                        color: menuRow.level <= 0.15 ? Theme.colorCritical : menuRow.level <= 0.3 ? Theme.colorWarning : Theme.colorAccent
                        Glide on width {}
                        Tint on color {}
                    }
                }
                ShellText
                {
                    width: parent.width - (menuRow.level >= 0 ? 28 : 0)
                    label: menuRow.subtitle
                    size: 10
                    color: Theme.text3
                }
            }
        }

        Item
        {
            id: tail
            anchors { right: parent.right; rightMargin: menuRow.showActions ? 6 : 10; verticalCenter: parent.verticalCenter }
            width: menuRow.showActions ? actionsRow.implicitWidth : marks.implicitWidth
            height: 24
            Glide on width {}

            Row
            {
                id: marks
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 6
                opacity: menuRow.showActions ? 0 : 1
                Smooth on opacity {}

                ShellText
                {
                    anchors.verticalCenter: parent.verticalCenter
                    label: menuRow.trailing
                    size: 11
                    color: Theme.text3
                }
                ShellIcon
                {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: menuRow.selected ? Icon.check : menuRow.trailingIcon
                    size: 14
                    opacity: menuRow.selected ? 1 : 0.6
                }
            }

            Row
            {
                id: actionsRow
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 2
                enabled: menuRow.showActions
                opacity: menuRow.showActions ? 1 : 0
                Smooth on opacity {}

            }
        }

        SequentialAnimation on opacity
        {
            running: menuRow.busy && Config.animationsEnabled && activity.active
            loops: Animation.Infinite
            onRunningChanged: if (!running) body.opacity = 1
            NumberAnimation { to: 0.45; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1;    duration: 500; easing.type: Easing.InOutSine }
        }
    }
}
