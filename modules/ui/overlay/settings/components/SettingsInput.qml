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

    implicitWidth: 260
    width: implicitWidth
    height: 32
    radius: Theme.radiusMedium
    opacity: enabled ? 1 : 0.4

    color: Theme.colorField
    border.width: 1
    border.color: editor.activeFocus ? Theme.colorAccent : Theme.colorHairline
    Tint on border.color {}

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
        font.pixelSize: Math.round(12 * Config.themeScale)

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
        color: Theme.text4
    }
}
