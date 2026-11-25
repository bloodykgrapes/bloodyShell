import QtQuick
import "../../../../common" as Common

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Common.InteractiveControl
{
    id: header

    property alias color: surface.color
    property alias radius: surface.radius
    property alias border: surface.border
    background: Rectangle { id: surface }

    property string title: ""
    property string description: ""
    property string icon: ""
    property string summary: ""
    property bool expanded: false

    signal toggled(bool expanded)

    implicitWidth: 400
    implicitHeight: Math.max(Theme.settingsRowHeight, labels.implicitHeight + 24)
    radius: Theme.radiusLarge
    color: area.pressed ? Theme.settingsColorPressed
        : header.hovered || visualFocus ? Theme.settingsColorHover : Theme.settingsColorCard
    activeFocusOnTab: true

    scale: Config.animationsFluid && area.pressed ? 0.99 : 1
    Spring on scale {}
    Tint on color {}

    Rectangle
    {
        id: symbol
        x: Theme.settingsRowInset
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: width
        radius: Theme.radiusMedium
        color: Theme.colorField
        visible: header.icon !== ""
        ShellIcon { anchors.centerIn: parent; icon: header.icon; size: 19 }
    }

    Column
    {
        id: labels
        anchors.verticalCenter: parent.verticalCenter
        x: symbol.visible ? symbol.x + symbol.width + 12 : Theme.settingsRowInset
        width: Math.max(0, trailing.x - x - 16)
        spacing: 4

        ShellText
        {
            width: parent.width
            label: header.title
            wrapMode: Text.Wrap
            size: Theme.settingsLabelSize
            font.weight: Font.Medium
            color: Theme.text1
        }
        ShellText
        {
            width: parent.width
            label: header.description
            size: 12
            wrapMode: Text.Wrap
            color: Theme.text3
        }
    }

    Row
    {
        id: trailing
        anchors { right: parent.right; rightMargin: Theme.settingsRowInset; verticalCenter: parent.verticalCenter }
        spacing: 10

        ShellText
        {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, header.width * 0.28)
            label: header.summary
            size: 12
            color: Theme.text3
        }
        Rectangle
        {
            width: 30
            height: 30
            radius: 9
            color: header.expanded ? Theme.colorField : "transparent"
            Tint on color {}

            ShellIcon
            {
                anchors.centerIn: parent
                icon: Icon.chevronRight
                size: 14
                rotation: header.expanded ? 90 : 0
                Glide on rotation { duration: Theme.animationDurationControl }
            }
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: header.focusFor(Qt.MouseFocusReason)
        onClicked: header.toggled(!header.expanded)
    }

    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) toggled(!expanded); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) toggled(!expanded); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) toggled(!expanded); event.accepted = true }
    Keys.onRightPressed: event => { toggled(true); event.accepted = true }
    Keys.onLeftPressed: event => { toggled(false); event.accepted = true }

    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: description
    Accessible.checkable: true
    Accessible.checked: expanded
    Accessible.onPressAction: if (enabled) toggled(!expanded)
}
