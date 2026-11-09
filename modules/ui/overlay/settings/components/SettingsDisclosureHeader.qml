import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Rectangle
{
    id: header

    property string title: ""
    property string description: ""
    property string icon: ""
    property string summary: ""
    property bool expanded: false
    property bool keyboardFocusHighlight: false

    signal toggled(bool expanded)

    implicitWidth: 400
    implicitHeight: Math.max(64, labels.implicitHeight + 28)
    radius: Theme.radiusLarge + 2
    color: area.pressed ? Theme.colorPressed
        : area.containsMouse || (activeFocus && keyboardFocusHighlight) ? Theme.colorHoverStrong : Theme.colorField
    activeFocusOnTab: true
    onActiveFocusChanged: keyboardFocusHighlight = activeFocus

    scale: Config.animationsFluid && area.pressed ? 0.99 : 1
    Spring on scale {}
    Tint on color {}

    Rectangle
    {
        id: symbol
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: 10
        visible: header.icon !== ""
        color: Theme.colorField

        ShellIcon { anchors.centerIn: parent; icon: header.icon; size: 17 }
    }

    Column
    {
        id: labels
        anchors.verticalCenter: parent.verticalCenter
        x: symbol.visible ? symbol.x + symbol.width + 12 : 16
        width: Math.max(0, trailing.x - x - 16)
        spacing: 4

        ShellText
        {
            width: parent.width
            label: header.title
            size: 13
            font.weight: Font.DemiBold
            color: Theme.text1
        }
        ShellText
        {
            width: parent.width
            label: header.description
            size: 11
            wrapMode: Text.Wrap
            color: Theme.text3
        }
    }

    Row
    {
        id: trailing
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 10

        ShellText
        {
            anchors.verticalCenter: parent.verticalCenter
            label: header.summary
            size: 11
            color: Theme.text3
        }
        Rectangle
        {
            width: 28
            height: 28
            radius: 9
            color: Theme.colorField

            ShellIcon
            {
                anchors.centerIn: parent
                icon: Icon.chevronRight
                size: 13
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
        onPressed: header.keyboardFocusHighlight = false
        onClicked:
        {
            header.forceActiveFocus();
            header.keyboardFocusHighlight = false;
            header.toggled(!header.expanded);
        }
    }

    Keys.onSpacePressed: event => { toggled(!expanded); event.accepted = true }
    Keys.onReturnPressed: event => { toggled(!expanded); event.accepted = true }
    Keys.onEnterPressed: event => { toggled(!expanded); event.accepted = true }
    Keys.onRightPressed: event => { toggled(true); event.accepted = true }
    Keys.onLeftPressed: event => { toggled(false); event.accepted = true }

    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: description
    Accessible.checkable: true
    Accessible.checked: expanded
    Accessible.onPressAction: toggled(!expanded)
}
