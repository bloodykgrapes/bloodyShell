import QtQuick

import ".."
import "../../core"

Row
{
    id: settingsStepper

    property real   value: 0
    property real   from: 0
    property real   to: 100
    property real   step: 1
    property int    decimals: 0
    property string suffix: ""

    signal edited(real value)

    function nudge(direction)
    {
        const next = Math.round((value + direction * step) * 1000) / 1000;
        edited(Math.max(from, Math.min(to, next)));
    }

    spacing: 4
    opacity: enabled ? 1 : 0.4

    SettingsIconButton
    {
        icon: Icon.minus
        autoRepeat: true
        enabled: settingsStepper.value > settingsStepper.from
        onClicked: settingsStepper.nudge(-1)
    }

    Rectangle
    {
        width: Math.max(64, valueText.implicitWidth + 16)
        height: 28
        radius: Theme.radiusMedium
        color: Theme.colorField

        ShellText
        {
            id: valueText
            anchors.centerIn: parent
            label: settingsStepper.value.toFixed(settingsStepper.decimals) + settingsStepper.suffix
            size: 12
            color: Theme.text1
            font.family: Theme.fontMono
        }
    }

    SettingsIconButton
    {
        icon: Icon.add
        autoRepeat: true
        enabled: settingsStepper.value < settingsStepper.to
        onClicked: settingsStepper.nudge(1)
    }
}
