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
    property string icon: ""
    property bool clearable: false
    readonly property real textLeftInset: icon !== "" ? 38 : 11
    readonly property real textRightInset: clearable && text !== "" ? 38 : 11

    function grabFocus() { editor.forceActiveFocus() }

    signal accepted()
    signal editingFinished()
    signal textEdited(string value)

    property real preferredWidth: 260
    implicitWidth: Math.round(preferredWidth)
    width: Theme.controlWidth(settingsInput, implicitWidth)
    height: Theme.controlHeight
    radius: Theme.radiusMedium
    opacity: enabled ? 1 : 0.4

    color: editor.activeFocus ? Theme.colorFieldFocus : Theme.colorField
    Tint on color {}

    MouseArea
    {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: editor.forceActiveFocus()
    }

    ShellIcon
    {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        icon: settingsInput.icon
        size: 16
        opacity: 0.65
    }

    TextInput
    {
        id: editor

        anchors { fill: parent; leftMargin: settingsInput.textLeftInset; rightMargin: settingsInput.textRightInset }
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
        font.pixelSize: Theme.controlTextSize

        onAccepted: settingsInput.accepted()
        onEditingFinished: settingsInput.editingFinished()
        onTextEdited: settingsInput.textEdited(text)
    }

    ShellText
    {
        anchors { fill: parent; leftMargin: settingsInput.textLeftInset; rightMargin: settingsInput.textRightInset }
        verticalAlignment: Text.AlignVCenter
        visible: editor.text === ""
        label: settingsInput.placeholderText
        size: Theme.controlTextSize
        color: Theme.text3
    }
    Button
    {
        iconOnly: true
        objectName: "clearSettingsInput"
        anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
        width: 24; height: 24; radius: 7
        visible: settingsInput.clearable && settingsInput.text !== ""
        icon: Icon.close
        iconSize: 10
        text: Tr.tr("launcher.clearSearch")
        activeFocusOnTab: false
        onClicked:
        {
            editor.text = "";
            settingsInput.textEdited("");
            editor.forceActiveFocus(Qt.MouseFocusReason);
        }
    }
}
