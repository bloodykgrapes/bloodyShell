import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../common" as Common
import "../../../../core"

Item
{
    id: settingsToggles

    property var options: []
    property var checked: []

    signal toggled(var value, bool on)

    readonly property var optionWidths:
    {
        metrics.font;
        return options.map(option => Math.ceil(metrics.advanceWidth(String(option.label))) + 41);
    }
    implicitWidth: optionWidths.reduce((sum, width) => sum + width, 0) + Math.max(0, options.length - 1) * spacing
    implicitHeight: flow.implicitHeight
    width: Theme.controlWidth(settingsToggles, implicitWidth)
    property alias spacing: flow.spacing
    opacity: enabled ? 1 : 0.4

    FontMetrics { id: metrics; font.family: Theme.fontText; font.pixelSize: 12 }

    Flow
    {
        id: flow
        width: parent.width
        spacing: 6

        Repeater
        {
            model: settingsToggles.options

            Common.InteractiveControl
            {
                id: chip
                property alias color: surface.color
                property alias radius: surface.radius
                property alias border: surface.border
                background: Rectangle { id: surface }

                required property var modelData
                required property int index

                readonly property bool on: settingsToggles.checked.indexOf(modelData.value) >= 0

                width: Math.min(settingsToggles.optionWidths[index], settingsToggles.width)
                height: Theme.settingsControlHeight
                radius: height / 2
                activeFocusOnTab: enabled
                border.width: visualFocus ? 1 : 0
                border.color: Theme.colorAccent
                Keys.onSpacePressed: event => { if (!event.isAutoRepeat) settingsToggles.toggled(modelData.value, !on); event.accepted = true }
                Keys.onReturnPressed: event => { if (!event.isAutoRepeat) settingsToggles.toggled(modelData.value, !on); event.accepted = true }

                Accessible.role: Accessible.CheckBox
                Accessible.name: modelData.label
                Accessible.checkable: true
                Accessible.checked: on
                Accessible.onToggleAction: if (enabled) settingsToggles.toggled(modelData.value, !on)

                color: on ? Theme.colorChosen : chip.hovered ? Theme.colorHover : Theme.colorField
                Tint on color {}

                scale: area.pressed ? 0.96 : chip.hovered ? 1.04 : 1
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
                        icon: Icon.check
                        opacity: chip.on ? 1 : 0
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
                    onPressed: chip.focusFor(Qt.MouseFocusReason)
                    onClicked: settingsToggles.toggled(chip.modelData.value, !chip.on)
                }
            }
        }
    }

}
