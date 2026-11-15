import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Rectangle
{
    id: settingsInput

    property alias  text: editor.text
    property string placeholderText: ""
    property bool   password: false

    function grabFocus() { editor.forceActiveFocus() }

    signal accepted()
    signal editingFinished()
    signal textEdited(string value)

    property real preferredWidth: 260
    implicitWidth: Math.round(preferredWidth)
    width: Theme.controlWidth(settingsInput, implicitWidth)
    height: Theme.settingsControlHeight
    radius: Theme.radiusMedium
    opacity: enabled ? 1 : 0.4

    color: Theme.colorField
    border.width: 1
    border.color: editor.activeFocus ? Theme.colorFocus : Theme.colorHairline
    Tint on border.color {}

    Rectangle
    {
        anchors.fill: parent
        anchors.margins: -3
        radius: settingsInput.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.accentShell ? Theme.accentAlpha(0.18) : Theme.inkAlpha(0.10)
        opacity: editor.activeFocus ? 1 : 0
        Smooth on opacity { duration: 160 }
    }

    MouseArea
    {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: editor.forceActiveFocus()
    }

    TextInput
    {
        id: editor

        anchors { fill: parent; leftMargin: 11; rightMargin: 11 }
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        selectByMouse: true
        activeFocusOnTab: true
        echoMode: settingsInput.password ? TextInput.Password : TextInput.Normal
        inputMethodHints: settingsInput.password ? Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase : Qt.ImhNone
        Accessible.name: settingsInput.placeholderText

        color: Theme.text1
        selectionColor: Theme.colorSelection
        selectedTextColor: Theme.text1
        font.family: Theme.fontText
        font.pixelSize: 13

        onAccepted: settingsInput.accepted()
        onEditingFinished: settingsInput.editingFinished()
        onTextEdited: settingsInput.textEdited(text)
    }

    ShellText
    {
        anchors { fill: parent; leftMargin: 11; rightMargin: 11 }
        verticalAlignment: Text.AlignVCenter
        visible: editor.text === ""
        label: settingsInput.placeholderText
        size: 13
        color: Theme.text3
    }
}
