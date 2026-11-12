import QtQuick
import QtQuick.Controls.Basic as Controls

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

    width: Math.min(460, Math.max(0, parent.width - 32))
    implicitHeight: body.implicitHeight + topPadding + bottomPadding
    x: (parent.width - width) / 2
    y: Math.max(16, (parent.height - height) / 2)

    onOpened: cancel.forceActiveFocus(Qt.PopupFocusReason)
    onAboutToHide: rejected()

    contentItem: Column
    {
        id: body
        spacing: 18
        Accessible.role: Accessible.Dialog
        Accessible.name: confirmation.title

        ShellText { id: heading; width: parent.width; label: confirmation.title; size: 18; font.bold: true; wrapMode: Text.Wrap }
        Flickable
        {
            id: details
            width: parent.width
            height: Math.min(descriptionLabel.implicitHeight, Math.max(40, confirmation.parent.height - heading.implicitHeight - buttons.implicitHeight - (failure.visible ? failure.implicitHeight + body.spacing : 0) - confirmation.topPadding - confirmation.bottomPadding - body.spacing * 2 - 32))
            contentWidth: width
            contentHeight: descriptionLabel.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height
            clip: true
            SmoothScroll { view: details }
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
            ShellText { id: descriptionLabel; width: Math.max(0, details.width - 12); label: confirmation.description; color: Theme.text2; wrapMode: Text.Wrap }
        }
        ShellText { id: failure; width: parent.width; visible: confirmation.errorText !== ""; label: confirmation.errorText; color: Theme.colorCritical; wrapMode: Text.Wrap }
        Row
        {
            id: buttons
            anchors.right: parent.right
            spacing: 10
            SettingsButton
            {
                id: cancel
                objectName: "cancelConfirmation"
                text: confirmation.cancelText
                maximumWidth: Math.max(0, (body.width - 10) * 0.4)
                onClicked: confirmation.close()
                KeyNavigation.tab: accept.enabled ? accept : cancel
                KeyNavigation.backtab: accept.enabled ? accept : cancel
            }
            SettingsButton
            {
                id: accept
                objectName: "acceptConfirmation"
                text: confirmation.acceptText
                maximumWidth: Math.max(0, body.width - cancel.width - 10)
                enabled: confirmation.acceptEnabled
                danger: confirmation.danger
                onClicked: confirmation.accepted()
                KeyNavigation.tab: cancel
                KeyNavigation.backtab: cancel
            }
        }
    }
}
