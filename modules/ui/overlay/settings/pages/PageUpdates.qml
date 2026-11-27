import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageUpdates

    title: Tr.tr("common.updates")
    subtitle: Tr.tr("settings.updates.description")

    property double now: Date.now()
    Timer { interval: 30000; running: pageUpdates.active; repeat: true; onTriggered: pageUpdates.now = Date.now() }

    readonly property string phase: ServiceUpdate.phase
    readonly property color  phaseColor: phase === "error" ? Theme.colorCritical
        : phase === "available" || phase === "installing" ? Theme.colorAttention
        : phase === "dev" ? Theme.colorWarning
        : Theme.text3

    SettingsRowGroup
    {
        Item
        {
            id: statusCard

            width: parent.width
            height: card.implicitHeight + 36

            HoverHandler { id: statusHover }
            SettingsTile { row: statusCard; hovered: statusHover.hovered && !OverlayState.settingsPopup }

            Column
            {
                id: card

                x: 18
                y: 18
                width: parent.width - 36
                spacing: 14

                Item
                {
                    id: statusHeading
                    readonly property bool compact: width < 620
                    width: parent.width
                    height: compact ? head.implicitHeight + 12 + actions.implicitHeight : Math.max(head.implicitHeight, actions.implicitHeight)

                    Rectangle
                    {
                        id: badge

                        y: Math.round((statusHeading.height - height) / 2)
                        width: 46
                        height: 46
                        radius: 23
                        color: Qt.rgba(pageUpdates.phaseColor.r, pageUpdates.phaseColor.g, pageUpdates.phaseColor.b, pageUpdates.phase === "current" || pageUpdates.phase === "unknown" ? 0.10 : 0.18)
                        Tint on color {}

                        ShellIcon
                        {
                            anchors.centerIn: parent
                            size: 20
                            icon: pageUpdates.phase === "checking" ? Icon.reload
                                : pageUpdates.phase === "current" ? Icon.check
                                : pageUpdates.phase === "error" ? Icon.close
                                : Icon.update

                            RotationAnimation on rotation
                            {
                                running: pageUpdates.visible && pageUpdates.phase === "checking" && Config.animationsEnabled
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 900
                            }
                            onIconChanged: rotation = 0
                        }
                    }

                    Column
                    {
                        id: head

                        y: statusHeading.compact ? 0 : (parent.height - implicitHeight) / 2
                        x: badge.width + 14
                        width: Math.max(0, parent.width - x - (statusHeading.compact ? 0 : actions.desiredWidth + 16))
                        spacing: 4

                        Flow
                        {
                            width: parent.width
                            spacing: 8

                            ShellText
                            {
                                label: "bloodyShell " + ServiceUpdate.version
                                size: 17
                                color: Theme.text1
                                font.bold: true
                            }
                            Chip { text: ServiceUpdate.currentRelease.prerelease ? Tr.tr("settings.updates.channelBeta") : Tr.tr("settings.updates.channelStable") }
                            Chip { visible: !ServiceUpdate.installed; text: Tr.tr("settings.updates.developmentCopy"); tint: Theme.colorWarning }
                        }
                        ShellText
                        {
                            width: parent.width
                            label: ServiceUpdate.status
                            size: 12
                            color: pageUpdates.phase === "current" || pageUpdates.phase === "unknown" ? Theme.text2 : pageUpdates.phaseColor
                            wrapMode: Text.Wrap
                        }
                        ShellText
                        {
                            width: parent.width
                            label: !ServiceUpdate.installed
                                ? Tr.tr("settings.updates.developmentCopyHint").arg(ServiceUpdate.pretty(ServiceUpdate.shellDir)).arg(ServiceUpdate.pretty(ServiceUpdate.installDir))
                                : Tr.tr("settings.updates.lastChecked").arg(ServiceUpdate.ago(ServiceUpdate.lastChecked, pageUpdates.now))
                            size: 11
                            color: Theme.text3
                            wrapMode: Text.Wrap
                        }
                        ShellText
                        {
                            visible: ServiceUpdate.installed && ServiceUpdate.pendingLoginVersion === ServiceUpdate.version
                            width: parent.width
                            label: Tr.tr("settings.updates.loginScreenPending")
                            size: 11
                            color: Theme.colorWarning
                            wrapMode: Text.Wrap
                        }
                    }

                    Flow
                    {
                        id: actions

                        readonly property real desiredWidth: children.reduce((total, child) => total + (child.visible ? child.implicitWidth + spacing : 0), -spacing)
                        x: statusHeading.compact ? head.x : parent.width - width
                        y: statusHeading.compact ? head.implicitHeight + 12 : (parent.height - height) / 2
                        width: statusHeading.compact ? Math.max(0, parent.width - badge.width - 14) : Math.max(0, desiredWidth)
                        spacing: 8

                        Button
                        {
                            maximumWidth: Math.max(0, statusHeading.width - badge.width - 14)
                            visible: pageUpdates.phase === "error" && ServiceUpdate.installFailed
                            text: Tr.tr("settings.updates.openLog")
                            onClicked: ServiceUpdate.openLog()
                        }
                        Button
                        {
                            maximumWidth: Math.max(0, statusHeading.width - badge.width - 14)
                            visible: !ServiceUpdate.availableUpdate || pageUpdates.phase === "error" || pageUpdates.phase === "dev"
                            text: pageUpdates.phase === "checking" ? Tr.tr("common.checking") : pageUpdates.phase === "error" ? Tr.tr("settings.updates.retry") : Tr.tr("settings.updates.checkNow")
                            icon: Icon.reload
                            enabled: ServiceUpdate.installed && !ServiceUpdate.busy
                            onClicked: ServiceUpdate.check()
                        }
                        Button
                        {
                            maximumWidth: Math.max(0, statusHeading.width - badge.width - 14)
                            visible: ServiceUpdate.installed && ServiceUpdate.availableUpdate && pageUpdates.phase !== "error"
                            text: pageUpdates.phase === "installing" ? Tr.tr("settings.updates.installing") : Tr.tr("settings.updates.updateTo").arg(ServiceUpdate.versionLatest)
                            icon: Icon.update
                            enabled: !ServiceUpdate.busy
                            onClicked: ServiceUpdate.update()
                        }
                    }
                }

                Column
                {
                    visible: pageUpdates.phase === "installing"
                    width: parent.width
                    spacing: 6

                    Rectangle
                    {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Theme.colorField

                        Rectangle
                        {
                            readonly property real share: ServiceUpdate.installSteps > 0 ? ServiceUpdate.installStep / ServiceUpdate.installSteps : 0.06

                            height: parent.height
                            radius: parent.radius
                            color: Theme.colorAttention
                            width: Math.max(height, parent.width * share)
                            Glide on width {}
                        }
                    }
                    ShellText
                    {
                        label: ServiceUpdate.installSteps > 0
                            ? Tr.tr("settings.updates.installProgress").arg(ServiceUpdate.installText).arg(Math.max(1, ServiceUpdate.installStep)).arg(ServiceUpdate.installSteps)
                            : ServiceUpdate.installText
                        size: 11
                        color: Theme.text3
                    }
                }

                Rectangle
                {
                    visible: ServiceUpdate.justUpdated
                    width: parent.width
                    height: updated.implicitHeight + 20
                    radius: Theme.radiusLarge
                    color: Theme.colorField

                    ShellText
                    {
                        id: updated
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 28
                        label: Tr.tr("settings.updates.updatedHint").arg(ServiceUpdate.updatedFrom).arg(ServiceUpdate.version)
                        size: 12
                        color: Theme.text2
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.updates.options")

        SettingsRow
        {
            label: Tr.tr("settings.updates.autoCheck")
            description: Tr.tr("settings.updates.autoCheckHint")

            enabled: ServiceUpdate.installed
            SettingsChoices
            {
                options:
                [
                    { label: Tr.tr("common.off"), value: 0 },
                    { label: Tr.tr("settings.updates.checkOnStartup"), value: 1 },
                    { label: Tr.tr("settings.updates.checkEvery6Hours"), value: 2 },
                    { label: Tr.tr("settings.updates.checkDaily"), value: 3 },
                    { label: Tr.tr("settings.updates.checkWeekly"), value: 4 }
                ]
                current: Config.updateCheck
                onSelected: value => Config.set("updateCheck", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.updates.autoUpdate")
            description: Tr.tr("settings.updates.autoUpdateHint")

            enabled: ServiceUpdate.installed
            Toggle
            {
                checked: Config.updateAuto;
                onToggled: value => Config.set("updateAuto", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.updates.channel")
            description: Tr.tr("settings.updates.channelHint")
            
            enabled: ServiceUpdate.installed
            SettingsChoices
            {
                options:
                [
                    { label: Tr.tr("settings.updates.channelStable"), value: false },
                    { label: Tr.tr("settings.updates.channelBeta"), value: true }
                ]
                current: Config.updateBeta
                onSelected: value => Config.set("updateBeta", value)
            }
        }
    }

    SettingsRowGroup
    {
        id: currentChangelog
        objectName: "currentChangelog"
        title: Tr.tr("settings.updates.changelog")
        summary: ServiceUpdate.version
        Component.onCompleted: ServiceUpdate.loadCurrentRelease()

        SettingsRow
        {
            objectName: "currentChangelogStatus"
            visible: !ServiceUpdate.currentNotes
            label: ServiceUpdate.currentNotesLoading ? Tr.tr("common.loading")
                : ServiceUpdate.currentNotesMissing ? Tr.tr("settings.updates.unpublished")
                : ServiceUpdate.currentNotesError ? Tr.tr("common.error") : Tr.tr("settings.updates.noReleaseNotes")
            description: ServiceUpdate.currentNotesError
            Button
            {
                objectName: "retryCurrentChangelog"
                text: Tr.tr("settings.updates.retry")
                visible: !ServiceUpdate.currentNotesLoading
                enabled: ServiceUpdate.versionReady
                onClicked: ServiceUpdate.loadCurrentRelease(true)
            }
        }

        Loader
        {
            width: parent.width
            active: ServiceUpdate.currentNotes !== null
            sourceComponent: SettingsReleaseCard
            {
                width: parent ? parent.width : 400
                release: ServiceUpdate.currentRelease
                repo: ServiceUpdate.repo
                collapsible: false
            }
        }
    }

    SettingsRowGroup
    {
        objectName: "pendingChangelogs"
        visible: ServiceUpdate.pending.length > 0
        title: Tr.tr("common.whatsNew")

        Repeater
        {
            model: ServiceUpdate.pending

            SettingsReleaseCard
            {
                required property var modelData
                release: modelData
                repo: ServiceUpdate.repo
            }
        }
    }
}
