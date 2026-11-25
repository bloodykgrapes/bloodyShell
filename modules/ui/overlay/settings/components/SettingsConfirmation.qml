import QtQuick

import "../../../../common"
import "../../../../core"

SettingsPopup
{
    id: confirmation

    property string title: ""
    property string description: ""
    property string errorText: ""
    required property string acceptText
    property string cancelText: Tr.tr("common.cancel")
    property bool acceptEnabled: true
    property bool danger: false
    signal accepted()
    signal rejected()

    onOpened: cancel.focusFor(keyboardNavigation ? Qt.TabFocusReason : Qt.MouseFocusReason)
    onAboutToHide: rejected()

    panelContent: SettingsPopupLayout
    {
        id: body
        anchors.fill: parent
        title: confirmation.title
        icon: confirmation.danger ? Icon.trash : Icon.confirmation
        errorText: confirmation.errorText
        ShellText
        {
            objectName: "confirmationDetails"
            width: parent.width
            visible: confirmation.description !== ""
            label: confirmation.description
            color: Theme.text2
            wrapMode: Text.Wrap
        }
        actions: [
            Button
            {
                id: cancel
                objectName: "cancelConfirmation"
                text: confirmation.cancelText
                maximumWidth: Math.max(0, (body.width - 10) * 0.4)
                onClicked: confirmation.close()
                KeyNavigation.tab: accept.enabled ? accept : cancel
                KeyNavigation.backtab: accept.enabled ? accept : cancel
            },
            Button
            {
                id: accept
                objectName: "acceptConfirmation"
                text: confirmation.acceptText
                maximumWidth: Math.max(0, body.width - cancel.width - 10)
                enabled: confirmation.acceptEnabled
                danger: confirmation.danger
                primary: !confirmation.danger
                onClicked: confirmation.accepted()
                KeyNavigation.tab: cancel
                KeyNavigation.backtab: cancel
            }
        ]
    }
}
