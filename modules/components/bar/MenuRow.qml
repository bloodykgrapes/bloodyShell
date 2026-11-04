import QtQuick

import ".."
import "../../core"

Item
{
    id: menuRow

    property string icon: ""
    property string text: ""
    property string subtitle: ""
    property string trailing: ""
    property string trailingIcon: ""
    property bool   selected: false
    property bool   busy: false
    property real   level: -1

    default property alias actions: actionsRow.data
    readonly property bool hasActions: actionsRow.children.length > 0
    readonly property bool hovered: area.containsMouse || actionsHover.hovered

    signal clicked()

    width: parent ? parent.width : 200
    height: subtitle !== "" || level >= 0 ? 42 : 34

    scale: area.pressed ? 0.98 : menuRow.hovered ? 1.025 : 1
    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: menuRow.selected ? Theme.colorCurrent : Theme.menuColorHover
        opacity: menuRow.selected || menuRow.hovered ? 1 : 0

        Smooth on opacity {}
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menuRow.clicked()
    }

    Item
    {
        id: body
        anchors.fill: parent

        ShellIcon
        {
            id: glyph
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            icon: menuRow.icon
            size: 16
            opacity: menuRow.selected ? 1 : 0.8
            zoom: 1.05
        }

        Column
        {
            anchors
            {
                left: glyph.visible ? glyph.right : parent.left
                leftMargin: 10
                right: tail.left
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            spacing: 1

            ShellText
            {
                width: parent.width
                label: menuRow.text
                size: 12
                color: menuRow.selected ? Theme.text1 : Theme.text2
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
            anchors { right: parent.right; rightMargin: menuRow.hasActions && menuRow.hovered ? 6 : 10; verticalCenter: parent.verticalCenter }
            width: menuRow.hasActions && menuRow.hovered ? actionsRow.implicitWidth : marks.implicitWidth
            height: 24
            Glide on width {}

            Row
            {
                id: marks
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 6
                opacity: menuRow.hasActions && menuRow.hovered ? 0 : 1
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
                visible: opacity > 0
                opacity: menuRow.hovered ? 1 : 0
                Smooth on opacity {}

                HoverHandler { id: actionsHover }
            }
        }

        SequentialAnimation on opacity
        {
            running: menuRow.visible && menuRow.busy && Config.animationsEnabled
            loops: Animation.Infinite
            onRunningChanged: if (!running) body.opacity = 1
            NumberAnimation { to: 0.45; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1;    duration: 500; easing.type: Easing.InOutSine }
        }
    }
}
