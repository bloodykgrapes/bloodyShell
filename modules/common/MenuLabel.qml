pragma ComponentBehavior: Bound

import QtQuick

import "../core"

Item
{
    id: menuLabel

    property string text: ""
    property bool   hint: false
    property bool   heading: false
    property string actionText: ""
    property string actionIcon: ""
    property bool actionEnabled: true

    signal actionTriggered()

    width: parent ? parent.width : 200
    height: hint || actionText !== "" ? 36 : heading ? 32 : 24

    ShellText
    {
        anchors
        {
            left: menuLabel.hint ? undefined : parent.left
            leftMargin: 10
            horizontalCenter: menuLabel.hint ? parent.horizontalCenter : undefined
            bottom: menuLabel.hint || action.active ? undefined : parent.bottom
            bottomMargin: 4
            verticalCenter: menuLabel.hint || action.active ? parent.verticalCenter : undefined
        }

        width: Math.max(0, menuLabel.width - 20 - (action.active ? action.width + 8 : 0))
        horizontalAlignment: menuLabel.hint ? Text.AlignHCenter : Text.AlignLeft
        label: menuLabel.hint || menuLabel.heading ? menuLabel.text : menuLabel.text.toUpperCase()
        size: menuLabel.hint || menuLabel.heading ? 12 : 10
        color: menuLabel.heading ? Theme.text2 : Theme.text3
        font.weight: menuLabel.heading ? Font.Medium : Font.Normal
        font.letterSpacing: menuLabel.hint || menuLabel.heading ? 0 : 0.8
    }

    Loader
    {
        id: action
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        active: menuLabel.actionText !== ""
        sourceComponent: ActionButton
        {
            height: 28
            text: menuLabel.actionText
            icon: menuLabel.actionIcon
            enabled: menuLabel.actionEnabled
            onClicked: menuLabel.actionTriggered()
        }
    }
}
