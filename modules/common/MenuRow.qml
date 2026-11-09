import QtQuick

import "../animations"
import "../core"

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
    property bool   prominent: false
    property bool   interactive: true
    property real   level: -1

    default property alias actions: actionsRow.data
    readonly property bool hasActions: actionsRow.children.some(child => child.visible)
    readonly property bool hovered: area.containsMouse || actionsHover.hovered || activeFocus
    readonly property bool showActions: hasActions && (prominent || hovered)
    readonly property MenuList view: ListView.view as MenuList

    RenderActivity { id: activity; target: menuRow }

    signal clicked()

    Accessible.role: interactive ? Accessible.Button : Accessible.StaticText
    Accessible.name: text + (subtitle !== "" ? ", " + subtitle : "")
    Accessible.onPressAction: if (enabled && interactive && !busy) clicked()

    width: view ? view.rowWidth : parent ? parent.width : 200
    height: prominent ? 58 : subtitle !== "" || level >= 0 ? 42 : 34

    scale: area.pressed ? 0.98 : interactive && menuRow.hovered ? 1.025 : 1
    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: menuRow.prominent ? Theme.radiusLarge : Theme.radiusMedium
        color: menuRow.selected ? Theme.colorCurrent : menuRow.prominent ? Theme.colorField : Theme.menuColorHover
        opacity: menuRow.prominent || menuRow.selected || menuRow.hovered ? 1 : 0

        Smooth on opacity {}
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: menuRow.interactive && !menuRow.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: menuRow.clicked()
    }

    Item
    {
        id: body
        anchors.fill: parent

        Rectangle
        {
            anchors.centerIn: glyph
            width: 36
            height: 36
            radius: 18
            visible: menuRow.prominent
            color: menuRow.selected ? Theme.colorChosen : Theme.colorHoverStrong
        }

        ShellIcon
        {
            id: glyph
            anchors { left: parent.left; leftMargin: menuRow.prominent ? 19 : 10; verticalCenter: parent.verticalCenter }
            icon: menuRow.icon
            size: menuRow.prominent ? 18 : 16
            opacity: menuRow.selected ? 1 : 0.8
            zoom: 1.05
        }

        Column
        {
            anchors
            {
                left: glyph.visible ? glyph.right : parent.left
                leftMargin: menuRow.prominent ? 19 : 10
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
                font.weight: menuRow.prominent ? Font.Medium : Font.Normal
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

                HoverHandler { id: actionsHover }
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
