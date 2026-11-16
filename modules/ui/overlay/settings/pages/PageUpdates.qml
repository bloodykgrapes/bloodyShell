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

    Component.onDestruction: { ServiceDependencies.pending = null; ServiceResources.pending = null; }

    property double now: Date.now()
    Timer { interval: 30000; running: pageUpdates.active; repeat: true; onTriggered: pageUpdates.now = Date.now() }

    readonly property string phase: ServiceUpdate.phase
    readonly property color  phaseColor: phase === "error" ? Theme.colorCritical
        : phase === "available" || phase === "installing" ? Theme.colorAttention
        : phase === "dev" ? Theme.colorWarning
        : Theme.text3

    function resourceTitle(entry)
    {
        if (!entry) return "";
        if (entry.kind === "compositor") return Tr.tr("settings.about.compositor");
        if (entry.kind === "dots") return Tr.tr("settings.imports.dots");
        if (entry.kind === "greeter") return Tr.tr("settings.imports.greeter");
        return Tr.tr("common.wallpapers");
    }

    SettingsConfirmation
    {
        objectName: "resourceConfirmation"
        readonly property var resource: ServiceResources.pending
        readonly property bool clearing: resource !== null && resource.action === "clear"
        readonly property bool direct: resource !== null && resource.kind === "wallpapers"
        host: pageUpdates
        visible: pageUpdates.active && ServiceResources.pending !== null
        title: clearing ? Tr.tr("settings.imports.clear") + " · " + pageUpdates.resourceTitle(resource)
            : Tr.tr("settings.imports.confirm") + " · " + pageUpdates.resourceTitle(ServiceResources.pending)
        description: !ServiceResources.pending ? ""
            : clearing ? Tr.tr("settings.imports.confirmClearGreeter")
            : ServiceResources.pending.kind === "greeter" ? Tr.tr("settings.imports.confirmGreeter")
            : ServiceResources.pending.kind === "compositor" ? Tr.tr("settings.imports.confirmNiri").arg(ServiceUpdate.pretty(ServiceResources.pending.destination))
            : ServiceResources.pending.kind === "dots" ? Tr.tr("settings.imports.confirmDots").arg((ServiceResources.pending.programs || []).join(", "))
            : Tr.tr("settings.imports.confirmWallpapers").arg(ServiceUpdate.pretty(ServiceResources.pending.destination))
        errorText: ServiceResources.error
        acceptText: direct ? Tr.tr(clearing ? "settings.imports.clear" : "settings.imports.import") : Tr.tr("settings.dependencies.continueInTerminal")
        danger: clearing
        acceptEnabled: !ServiceResources.busy && !ServiceUpdate.busy
        onAccepted: ServiceResources.apply()
        onRejected: ServiceResources.pending = null
    }

    SettingsConfirmation
    {
        objectName: "dependencyConfirmation"
        host: pageUpdates
        visible: pageUpdates.active && ServiceDependencies.pending !== null
        title: Tr.tr("settings.dependencies.confirm")
        description: ServiceDependencies.pending
            ? (ServiceDependencies.pending.remove ? Tr.tr("settings.dependencies.confirmRemove") : Tr.tr("settings.dependencies.confirmInstall")).arg(ServiceDependencies.pending.name) : ""
        errorText: ServiceDependencies.error
        acceptText: Tr.tr("settings.dependencies.continueInTerminal")
        acceptEnabled: !ServiceDependencies.busy
        danger: ServiceDependencies.pending !== null && ServiceDependencies.pending.remove
        onAccepted: ServiceDependencies.apply()
        onRejected: ServiceDependencies.pending = null
    }

    SettingsGroup
    {
        title: Tr.tr("common.status")

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
                    }

                    Flow
                    {
                        id: actions

                        readonly property real desiredWidth: children.reduce((total, child) => total + (child.visible ? child.implicitWidth + spacing : 0), -spacing)
                        x: statusHeading.compact ? head.x : parent.width - width
                        y: statusHeading.compact ? head.implicitHeight + 12 : (parent.height - height) / 2
                        width: statusHeading.compact ? Math.max(0, parent.width - badge.width - 14) : Math.max(0, desiredWidth)
                        spacing: 8

                        SettingsButton
                        {
                            maximumWidth: Math.max(0, statusHeading.width - badge.width - 14)
                            visible: pageUpdates.phase === "error" && ServiceUpdate.installFailed
                            text: Tr.tr("settings.updates.openLog")
                            onClicked: ServiceUpdate.openLog()
                        }
                        SettingsButton
                        {
                            maximumWidth: Math.max(0, statusHeading.width - badge.width - 14)
                            visible: !ServiceUpdate.availableUpdate || pageUpdates.phase === "error" || pageUpdates.phase === "dev"
                            text: pageUpdates.phase === "checking" ? Tr.tr("common.checking") : pageUpdates.phase === "error" ? Tr.tr("settings.updates.retry") : Tr.tr("settings.updates.checkNow")
                            icon: Icon.reload
                            enabled: ServiceUpdate.installed && !ServiceUpdate.busy
                            onClicked: ServiceUpdate.check()
                        }
                        SettingsButton
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

    SettingsGroup
    {
        title: Tr.tr("settings.updates.options")

        SettingsRow
        {
            label: Tr.tr("settings.updates.channel")
            description: Tr.tr("settings.updates.channelHint")

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

            Toggle { checked: Config.updateAuto; onToggled: value => Config.set("updateAuto", value) }
        }
    }

    SettingsDisclosure
    {
        objectName: "resourceImports"
        title: Tr.tr("settings.imports.title")
        description: Tr.tr("settings.imports.description")
        icon: Icon.importFiles
        summary: ServiceResources.busy ? Tr.tr("common.working") : ""
        onExpandedChanged:
        {
            if (expanded) ServiceResources.refresh();
            else ServiceResources.pending = null;
        }

        SettingsRow
        {
            visible: ServiceResources.error !== ""
            label: Tr.tr("common.error")
            description: ServiceResources.error
            SettingsButton
            {
                text: Tr.tr("common.refresh")
                enabled: !ServiceResources.busy && !ServiceUpdate.busy && ServiceResources.pending === null
                onClicked: ServiceResources.refresh()
            }
        }
        Repeater
        {
            model: ServiceResources.entries
            SettingsRow
            {
                id: resourceRow
                required property var modelData
                objectName: "importRow-" + modelData.id
                label: pageUpdates.resourceTitle(modelData)
                icon: modelData.kind === "greeter" ? Icon.loginScreen
                    : modelData.kind === "compositor" ? Icon.compositor
                    : modelData.kind === "dots" ? Icon.configuration : Icon.wallpapers
                description: resourceRow.modelData.kind === "greeter" ? Tr.tr("settings.imports.greeterHint")
                    : resourceRow.modelData.kind === "compositor" ? Tr.tr("settings.imports.niriHint").arg(ServiceUpdate.pretty(resourceRow.modelData.destination))
                    : resourceRow.modelData.kind === "dots" ? Tr.tr("settings.imports.dotsHint")
                    : Tr.tr("settings.imports.wallpapersHint").arg(ServiceUpdate.pretty(resourceRow.modelData.destination))
                Row
                {
                    spacing: 8
                    SettingsButton
                    {
                        objectName: "clearResource-" + resourceRow.modelData.id
                        visible: resourceRow.modelData.kind === "greeter"
                        text: ServiceResources.operation === resourceRow.modelData.id && ServiceResources.operationAction === "clear" ? Tr.tr("common.working") : Tr.tr("settings.imports.clear")
                        danger: true
                        enabled: resourceRow.modelData.installed === true && !ServiceResources.busy && !ServiceUpdate.busy && ServiceResources.pending === null
                        onClicked: ServiceResources.request(resourceRow.modelData.id, "clear")
                    }
                    SettingsButton
                    {
                        objectName: "importResource-" + resourceRow.modelData.id
                        text: ServiceResources.operation === resourceRow.modelData.id && ServiceResources.operationAction === "import" ? Tr.tr("common.working") : Tr.tr("settings.imports.import")
                        enabled: !ServiceResources.busy && !ServiceUpdate.busy && ServiceResources.pending === null
                            && resourceRow.modelData.available === true
                        onClicked: ServiceResources.request(resourceRow.modelData.id)
                    }
                }
            }
        }
    }

    PackageList
    {
        objectName: "optionalPackages"
        title: Tr.tr("settings.packages.title")
        description: Tr.tr("settings.packages.description")
        requiredPackages: false
    }

    PackageList
    {
        objectName: "requiredDependencies"
        title: Tr.tr("settings.dependencies.title")
        description: Tr.tr("settings.dependencies.description")
        requiredPackages: true
    }

    component PackageList: SettingsDisclosure
    {
        id: packageList

        required property bool requiredPackages
        readonly property var entries: requiredPackages ? ServiceDependencies.dependencies : ServiceDependencies.packages

        icon: Icon.packages
        summary: ServiceDependencies.busy ? Tr.tr("common.checking")
            : entries.length > 0 ? entries.filter(entry => entry.installed).length + " / " + entries.length : ""
        onExpandedChanged:
        {
            if (expanded) ServiceDependencies.refresh();
            else ServiceDependencies.pending = null;
        }

        SettingsRow
        {
            visible: ServiceDependencies.error !== ""
            label: Tr.tr("settings.dependencies.error")
            description: ServiceDependencies.error
            SettingsButton { text: Tr.tr("common.refresh"); onClicked: ServiceDependencies.refresh(); enabled: !ServiceDependencies.busy }
        }
        Repeater
        {
            model: packageList.entries
            SettingsRow
            {
                id: dependencyRow
                required property var modelData
                objectName: "packageRow-" + modelData.tool
                label: modelData.packages.length ? modelData.packages.join(", ") : modelData.tool
                description: packageList.requiredPackages ? "" : ServiceDependencies.description(modelData)
                valueText: dependencyRow.modelData.installed ? Tr.tr("common.installed") : Tr.tr("common.notInstalled")
                SettingsButton
                {
                    objectName: "packageAction-" + dependencyRow.modelData.tool
                    visible: !dependencyRow.modelData.installed || (!packageList.requiredPackages && dependencyRow.modelData.removable)
                    text: ServiceDependencies.operation === dependencyRow.modelData.tool ? Tr.tr("common.working")
                        : !dependencyRow.modelData.supported ? Tr.tr("settings.dependencies.manual")
                        : dependencyRow.modelData.installed ? Tr.tr("common.remove") : Tr.tr("common.install")
                    danger: dependencyRow.modelData.installed
                    enabled: dependencyRow.modelData.supported && !ServiceDependencies.busy && ServiceDependencies.pending === null
                    onClicked: ServiceDependencies.request(dependencyRow.modelData.tool, dependencyRow.modelData.installed)
                }
            }
        }
    }

    SettingsDisclosure
    {
        id: currentChangelog
        objectName: "currentChangelog"
        title: Tr.tr("settings.updates.changelog")
        summary: ServiceUpdate.version
        icon: Icon.update
        onExpandedChanged: if (expanded) ServiceUpdate.loadCurrentRelease()

        SettingsRow
        {
            objectName: "currentChangelogStatus"
            visible: currentChangelog.expanded && !ServiceUpdate.currentNotes
            label: ServiceUpdate.currentNotesLoading ? Tr.tr("common.loading")
                : ServiceUpdate.currentNotesMissing ? Tr.tr("settings.updates.unpublished")
                : ServiceUpdate.currentNotesError ? Tr.tr("common.error") : Tr.tr("settings.updates.noReleaseNotes")
            description: ServiceUpdate.currentNotesError
            SettingsButton
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
            active: currentChangelog.expanded && ServiceUpdate.currentNotes !== null
            sourceComponent: SettingsReleaseCard
            {
                width: parent ? parent.width : 400
                release: ServiceUpdate.currentRelease
                repo: ServiceUpdate.repo
                collapsible: false
            }
        }
    }

    SettingsGroup
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
