pragma ComponentBehavior: Bound

import QtQuick

Flow
{
    id: choices

    required property string kind
    required property var options
    property int current: 0
    property int preferredCardWidth: 150
    property string namePrefix: ""
    signal selected(int value)

    width: parent ? parent.width : implicitWidth
    spacing: 10

    Repeater
    {
        model: choices.options

        SettingsStyleCard
        {
            required property var modelData
            objectName: choices.namePrefix === "" ? "" : choices.namePrefix + modelData.value
            kind: choices.kind
            width: Math.max(1, Math.min(choices.preferredCardWidth, (choices.width - choices.spacing * (choices.options.length - 1)) / Math.max(1, choices.options.length)))
            value: modelData.value
            label: modelData.label
            current: choices.current === modelData.value
            onClicked: choices.selected(modelData.value)
        }
    }
}
