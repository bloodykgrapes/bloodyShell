pragma ComponentBehavior: Bound

import QtQuick

import "../core"

Column
{
    id: credentials

    property bool enterprise: false
    property bool busy: false
    property var details: ({ profile: false, username: "", method: "peap", inner: "mschapv2", domain: "", certificate: "" })
    property string method: "peap"
    property string inner: "mschapv2"
    property bool advanced: false
    property bool ready: false
    readonly property string username: login.text.trim()
    readonly property string password: secret.text
    readonly property bool supported: !enterprise || !details.profile || ["peap", "ttls", "pwd"].includes(details.method)
    readonly property bool canSubmit: !busy && supported && password !== "" && (!enterprise || username !== "")
    readonly property var options: ({ method: method, inner: inner, domain: domain.text.trim(), certificate: certificate.text.trim() })

    signal submitted()
    signal cancelled()

    spacing: 8
    Component.onCompleted: { ready = true; applyDetails(); }
    onVisibleChanged: if (ready) { if (visible) applyDetails(); else reset(); }
    onDetailsChanged: if (ready && visible) applyDetails()
    function applyDetails()
    {
        login.text = details.username || "";
        method = details.method || "peap";
        inner = details.inner || "mschapv2";
        domain.text = details.domain || "";
        certificate.text = details.certificate || "";
    }
    function clearSecret() { secret.text = "" }
    function reset() { clearSecret(); login.text = ""; domain.text = ""; certificate.text = ""; advanced = false }
    function grabFocus() { if (enterprise && login.text === "") login.grabFocus(); else secret.grabFocus() }
    Keys.onEscapePressed: cancelled()

    component Field: Rectangle
    {
        id: field
        property alias text: editor.text
        property string placeholder: ""
        property bool conceal: false
        signal accepted()
        function grabFocus() { editor.forceActiveFocus() }
        width: credentials.width
        height: 34
        radius: Theme.radiusMedium
        color: Theme.colorField
        border.width: 1
        border.color: editor.activeFocus ? Theme.colorAccent : Theme.colorHairline
        TextInput
        {
            id: editor
            anchors { fill: parent; leftMargin: 11; rightMargin: 11 }
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            selectByMouse: true
            readOnly: credentials.busy
            color: Theme.text1
            selectionColor: Theme.colorSelection
            font.family: Theme.fontText
            font.pixelSize: Math.round(12 * Config.themeScale)
            echoMode: field.conceal ? TextInput.Password : TextInput.Normal
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | (field.conceal ? Qt.ImhSensitiveData : 0)
            onAccepted: field.accepted()
            Accessible.name: field.placeholder
        }
        ShellText { anchors { fill: parent; leftMargin: 11; rightMargin: 11 } verticalAlignment: Text.AlignVCenter; visible: editor.text === ""; label: field.placeholder; color: Theme.text4 }
    }

    Field { id: login; visible: credentials.enterprise; placeholder: Tr.tr("settings.networks.username"); onAccepted: secret.grabFocus() }
    Field { id: secret; conceal: true; placeholder: Tr.tr("common.password"); onAccepted: if (credentials.canSubmit) credentials.submitted() }
    ShellText
    {
        width: parent.width
        visible: !credentials.supported
        label: Tr.tr("service.network.unsupportedMethod")
        wrapMode: Text.Wrap
        size: 11
        color: Theme.colorWarning
    }
    ActionButton
    {
        visible: credentials.enterprise && !credentials.details.profile
        text: Tr.tr("settings.networks.connectionSettings")
        enabled: !credentials.busy
        onClicked: credentials.advanced = !credentials.advanced
    }
    Column
    {
        visible: credentials.enterprise && !credentials.details.profile && credentials.advanced
        width: parent.width
        spacing: 8
        Field { id: domain; placeholder: Tr.tr("settings.networks.serverDomain"); onAccepted: if (credentials.canSubmit) credentials.submitted() }
        ShellText
        {
            width: parent.width
            label: Tr.tr("settings.networks.serverDomainHint")
            wrapMode: Text.Wrap
            size: 10
            color: Theme.text3
        }
        Row
        {
            spacing: 6
            Repeater
            {
                model: ["peap", "ttls"]
                ActionButton
                {
                    required property string modelData
                    text: modelData.toUpperCase()
                    color: credentials.method === modelData ? Theme.colorChosen : Theme.colorField
                    enabled: !credentials.busy
                    onClicked: { credentials.method = modelData; credentials.inner = modelData === "peap" ? "mschapv2" : "pap"; }
                }
            }
        }
        Row
        {
            spacing: 6
            Repeater
            {
                model: credentials.method === "peap" ? ["mschapv2", "gtc"] : ["pap", "mschapv2"]
                ActionButton
                {
                    required property string modelData
                    text: modelData.toUpperCase()
                    color: credentials.inner === modelData ? Theme.colorChosen : Theme.colorField
                    enabled: !credentials.busy
                    onClicked: credentials.inner = modelData
                }
            }
        }
        Field { id: certificate; placeholder: Tr.tr("settings.networks.caCertificate") }
    }
    Row
    {
        spacing: 8
        ActionButton { text: credentials.busy ? Tr.tr("common.connecting") : Tr.tr("menu.network.join"); enabled: credentials.canSubmit; onClicked: credentials.submitted() }
        ActionButton { text: Tr.tr("common.cancel"); onClicked: credentials.cancelled() }
    }
}
