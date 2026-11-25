import QtQuick
import "../../../../common" as Common

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Common.InteractiveControl
{
    id: settingsTab


    property string icon: ""
    property string title: ""
    property bool   selected: false

    signal clicked()

    readonly property bool highlighted: enabled && (hovered || visualFocus)

    width: parent ? parent.width : 200
    height: Math.max(Theme.settingsTabHeight, titleText.implicitHeight + 12)
    activeFocusOnTab: enabled
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }

    Accessible.role: Accessible.PageTab
    Accessible.name: title
    Accessible.selected: selected
    Accessible.onPressAction: if (enabled) clicked()

    scale: area.pressed ? 0.98 : settingsTab.hovered ? 1.015 : 1
    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: 9

        color: Qt.tint(Theme.settingsColorSidebar, Theme.colorHover)
        opacity: settingsTab.highlighted && !settingsTab.selected ? 1 : 0
        Smooth on opacity { duration: 160 }
    }

    Row
    {
        x: 8
        width: parent.width - 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        Rectangle
        {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 7
            color: settingsTab.selected ? Theme.inkAlpha(0.1) : Theme.colorField
            Tint on color {}
            ShellIcon
            {
                anchors.centerIn: parent
                icon: settingsTab.icon
                size: 16
                opacity: settingsTab.selected ? 1 : 0.8
                Smooth on opacity { duration: 200 }
            }
        }
        ShellText
        {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - glyph.width - parent.spacing)
            label: settingsTab.title
            wrapMode: Text.Wrap
            size: 13
            font.weight: settingsTab.selected ? Font.DemiBold : Font.Medium
            color: settingsTab.selected ? Theme.text1 : Theme.text2
            Tint on color { duration: 200 }
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: settingsTab.focusFor(Qt.MouseFocusReason)
        onClicked: settingsTab.clicked()
    }
}
