import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Dialogs
import QtQuick.Window
import Quickshell.Widgets

import "../../../../animations"
import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageUser

    title: Tr.tr("common.user")
    subtitle: Tr.tr("settings.user.description")

    Component.onCompleted: ServiceUser.refresh()
    Component.onDestruction: ServiceUser.cancelApply()

    component AccountInput: SettingsInput
    {
        required property string field
        width: 300
        enabled: ServiceUser.loaded && !ServiceUser.busy && !ServiceUser.confirming
        text: String(ServiceUser.draft[field] || "")
        onTextEdited: value => ServiceUser.edit(field, value)
    }

    SettingsGroup
    {
        title: Tr.tr("settings.user.profile")

        SettingsRow
        {
            label: Tr.tr("settings.user.profilePicture")
            description: Tr.tr("settings.user.pictureHint")
            stacked: true

            Row
            {
                width: parent.width
                spacing: 14

                ClippingRectangle
                {
                    width: 76
                    height: 76
                    radius: 38
                    color: Theme.colorField

                    ShellIcon
                    {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        icon: Icon.user
                        size: 28
                        opacity: 0.7
                    }

                    Image
                    {
                        id: face
                        anchors.fill: parent
                        source: ServiceUser.avatarPreview !== "" ? "file://" + ServiceUser.avatarPreview : ""
                        sourceSize: Qt.size(152, 152)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        opacity: status === Image.Ready ? 1 : 0
                        Smooth on opacity { duration: 180 }
                    }
                }

                Column
                {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    SettingsButton
                    {
                        text: ServiceUser.avatarBusy ? Tr.tr("common.working") : Tr.tr("settings.user.choosePicture")
                        icon: Icon.user
                        enabled: ServiceUser.loaded && !ServiceUser.busy && !ServiceUser.confirming
                        onClicked: avatarDialog.open()
                    }

                    SettingsButton
                    {
                        text: Tr.tr("settings.user.resetPicture")
                        icon: Icon.reload
                        visible: ServiceUser.avatarPreview !== ""
                        enabled: ServiceUser.loaded && !ServiceUser.busy && !ServiceUser.confirming
                        onClicked: ServiceUser.resetAvatar()
                    }
                }
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.user.displayName")
            AccountInput { field: "fullName" }
        }
        SettingsRow
        {
            label: Tr.tr("settings.user.username")
            AccountInput { field: "username" }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.user.accountDetails")
        subtitle: Tr.tr("settings.user.sessionHint")

        SettingsRow { label: Tr.tr("settings.user.userId"); AccountInput { field: "uid" } }
        SettingsRow { label: Tr.tr("settings.user.primaryGroupId"); AccountInput { field: "gid" } }
        SettingsRow
        {
            label: Tr.tr("settings.user.homeDirectory")
            description: Tr.tr("settings.user.homeDirectoryHint")
            AccountInput { field: "homeDirectory" }
        }
        SettingsRow
        {
            label: Tr.tr("settings.user.loginShell")
            SettingsCombo
            {
                width: 300
                enabled: ServiceUser.loaded && !ServiceUser.busy && !ServiceUser.confirming
                options: ServiceUser.shells.map(shell => ({ label: shell, value: shell }))
                current: ServiceUser.draft.loginShell || ""
                onSelected: value => ServiceUser.edit("loginShell", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.user.supplementaryGroups")
            description: Tr.tr("settings.user.groupsHint")
            AccountInput { field: "groups" }
        }
    }

    SettingsRow
    {
        visible: !ServiceUser.confirming
        label: ServiceUser.busy ? Tr.tr("common.working") : Tr.tr("settings.user.pendingChanges")
        description: Tr.tr("settings.user.applyHint")

        Row
        {
            spacing: 8
            SettingsButton
            {
                text: Tr.tr("settings.user.discard")
                enabled: ServiceUser.loaded && ServiceUser.hasChanges && !ServiceUser.busy
                onClicked: ServiceUser.resetDraft()
            }
            SettingsButton
            {
                text: Tr.tr("common.apply")
                enabled: ServiceUser.loaded && ServiceUser.hasChanges && !ServiceUser.busy
                onClicked: ServiceUser.prepareApply()
            }
        }
    }

    SettingsGroup
    {
        visible: ServiceUser.confirming
        title: Tr.tr("settings.user.confirmChanges")
        subtitle: Tr.tr("settings.user.confirmHint")

        Repeater
        {
            model: ServiceUser.confirmationChanges
            SettingsRow
            {
                required property var modelData
                label: modelData.label
                description: (modelData.before || Tr.tr("common.empty")) + " → " + (modelData.after || Tr.tr("common.empty"))
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.user.readyToApply")
            Row
            {
                spacing: 8
                SettingsButton
                {
                    text: Tr.tr("common.cancel")
                    onClicked: ServiceUser.cancelApply()
                }
                SettingsButton
                {
                    text: Tr.tr("settings.user.confirmApply")
                    onClicked: ServiceUser.confirmApply()
                }
            }
        }
    }

    SettingsRow
    {
        visible: ServiceUser.message !== ""
        label: Tr.tr("common.status")
        description: ServiceUser.message
    }

    SettingsRow
    {
        visible: ServiceUser.error !== ""
        label: Tr.tr("common.actionFailed")
        description: ServiceUser.error
        badge: Tr.tr("common.error")
        badgeColor: Theme.colorCritical
    }

    FileDialog
    {
        id: avatarDialog
        parentWindow: pageUser.Window.window
        title: Tr.tr("settings.user.chooseProfilePicture")
        options: FileDialog.DontUseNativeDialog
        popupType: Controls.Popup.Item
        modality: Qt.WindowModal
        fileMode: FileDialog.OpenFile
        nameFilters: [Tr.tr("common.images") + " (*.png *.jpg *.jpeg *.webp *.bmp *.gif)"]
        onAccepted: ServiceUser.setAvatar(selectedFile)
    }
}
