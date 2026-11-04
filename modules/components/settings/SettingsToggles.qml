import QtQuick

import ".."
import "../../core"

Flow
{
    id: settingsToggles

    property var options: []
    property var checked: []

    signal toggled(var value, bool on)

    width: parent ? parent.width : 400
    spacing: 6
    opacity: enabled ? 1 : 0.4

    Repeater
    {
        model: settingsToggles.options

        Rectangle
        {
            id: chip

            required property var modelData

            readonly property bool on: settingsToggles.checked.indexOf(modelData.value) >= 0

            width: content.implicitWidth + 24
            height: 28
            radius: height / 2

            color: on ? Theme.colorChosen : area.containsMouse ? Theme.colorHover : Theme.colorField
            Tint on color {}

            scale: area.pressed ? 0.96 : area.containsMouse ? 1.04 : 1
            Spring on scale {}

            Row
            {
                id: content
                anchors.centerIn: parent
                spacing: 6

                ShellIcon
                {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: chip.on ? Icon.check : ""
                    size: 11
                }
                ShellText
                {
                    anchors.verticalCenter: parent.verticalCenter
                    label: chip.modelData.label
                    color: chip.on ? Theme.text1 : Theme.text3
                }
            }

            MouseArea
            {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: settingsToggles.toggled(chip.modelData.value, !chip.on)
            }
        }
    }
}
