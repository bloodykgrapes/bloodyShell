import QtQuick

import "../core"

MenuItem
{
    id: menuToggle

    property bool checked: false
    signal toggle(bool value)

    iconSize: 18
    textSize: 13
    trailingInset: 44
    actionPressed: control.pressed
    onClicked: toggle(!checked)

    Toggle
    {
        id: control
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        width: 34
        height: 18
        checked: menuToggle.checked
        inset: 2
        thumbStretch: 0
        thumbBorderWidth: 0
        pressScale: 1
        hoverScale: 1
        disabledOpacity: 1
        uncheckedColor: Theme.colorLine
        checkedThumbColor: Theme.colorSolid
        uncheckedThumbColor: Theme.text3
        Accessible.name: menuToggle.text
        onToggled: value => menuToggle.toggle(value)
    }
}
