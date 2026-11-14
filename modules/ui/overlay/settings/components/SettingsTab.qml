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
    height: Math.max(Theme.settingsTabHeight, titleText.implicitHeight + 16)
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
        radius: Theme.radiusLarge - 2

        color: Theme.colorHover
        opacity: settingsTab.highlighted && !settingsTab.selected ? 1 : 0
        Smooth on opacity { duration: 160 }
    }

    Row
    {
        x: 12
        width: parent.width - 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 11

        ShellIcon
        {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            icon: settingsTab.icon
            size: 16
            zoom: 1.05
            opacity: settingsTab.selected ? 1 : 0.85
            Smooth on opacity { duration: 200 }
        }
        ShellText
        {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - glyph.width - parent.spacing)
            label: settingsTab.title
            wrapMode: Text.Wrap
            size: 13
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
