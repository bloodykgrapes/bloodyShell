import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../core"

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

            width: Math.min(chipText.implicitWidth + (glyph.visible ? glyph.width + content.spacing : 0) + 24, settingsToggles.width)
            height: Theme.settingsControlHeight
            radius: height / 2
            activeFocusOnTab: enabled
            border.width: activeFocus ? 1 : 0
            border.color: Theme.colorAccent
            Keys.onSpacePressed: event => { if (!event.isAutoRepeat) settingsToggles.toggled(modelData.value, !on); event.accepted = true }
            Keys.onReturnPressed: event => { if (!event.isAutoRepeat) settingsToggles.toggled(modelData.value, !on); event.accepted = true }

            Accessible.role: Accessible.CheckBox
            Accessible.name: modelData.label
            Accessible.checkable: true
            Accessible.checked: on
            Accessible.onToggleAction: if (enabled) settingsToggles.toggled(modelData.value, !on)

            color: on ? Theme.colorChosen : area.containsMouse ? Theme.colorHover : Theme.colorField
            Tint on color {}

            scale: area.pressed ? 0.96 : area.containsMouse ? 1.04 : 1
            Spring on scale {}

            Row
            {
                id: content
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 6

                ShellIcon
                {
                    id: glyph
                    anchors.verticalCenter: parent.verticalCenter
                    icon: chip.on ? Icon.check : ""
                    size: 11
                }
                ShellText
                {
                    id: chipText
                    width: Math.max(0, content.width - (glyph.visible ? glyph.width + content.spacing : 0))
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
