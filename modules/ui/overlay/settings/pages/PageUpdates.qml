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

    function date(iso)
    {
        const d = new Date(iso);
        return isNaN(d.getTime()) ? "" : d.toLocaleDateString(Tr.locale, "d MMM yyyy");
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
                    width: parent.width
                    height: Math.max(head.implicitHeight, actions.height)

                    Rectangle
                    {
                        id: badge

                        anchors.verticalCenter: parent.verticalCenter
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

                        anchors.verticalCenter: parent.verticalCenter
                        x: badge.width + 14
                        width: parent.width - x - actions.width - 16
                        spacing: 4

                        Row
                        {
                            spacing: 8

                            ShellText
                            {
                                anchors.verticalCenter: parent.verticalCenter
                                label: "bloodyShell " + ServiceUpdate.version
                                size: 17
                                color: Theme.text1
                                font.bold: true
                            }
                            Chip { text: Config.updateBeta ? Tr.tr("settings.updates.channelBeta") : Tr.tr("settings.updates.channelStable") }
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

                    Row
                    {
                        id: actions

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        SettingsButton
                        {
                            visible: pageUpdates.phase === "error" && ServiceUpdate.installFailed
                            text: Tr.tr("settings.updates.openLog")
                            onClicked: ServiceUpdate.openLog()
                        }
                        SettingsButton
                        {
                            visible: !ServiceUpdate.availableUpdate || pageUpdates.phase === "error" || pageUpdates.phase === "dev"
                            text: pageUpdates.phase === "checking" ? Tr.tr("common.checking") : pageUpdates.phase === "error" ? Tr.tr("settings.updates.retry") : Tr.tr("settings.updates.checkNow")
                            icon: Icon.reload
                            enabled: ServiceUpdate.installed && !ServiceUpdate.busy
                            onClicked: ServiceUpdate.check()
                        }
                        SettingsButton
                        {
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
        icon: Icon.add
        onExpandedChanged:
        {
            if (expanded) ServiceResources.refresh();
            else ServiceResources.pending = null;
        }

        SettingsRow
        {
            label: Tr.tr("settings.imports.source")
            description: ServiceResources.source === "local" ? Tr.tr("settings.imports.localSource") : Tr.tr("settings.imports.repositorySource")
            SettingsButton { text: ServiceResources.busy ? Tr.tr("common.working") : Tr.tr("common.refresh"); enabled: !ServiceResources.busy && !ServiceUpdate.busy; onClicked: ServiceResources.refresh() }
        }
        SettingsRow
        {
            visible: ServiceResources.error !== "" || ServiceResources.message !== ""
            label: ServiceResources.error !== "" ? Tr.tr("common.error") : Tr.tr("settings.imports.finished")
            description: ServiceResources.error || ServiceResources.message
        }
        SettingsRow
        {
            visible: ServiceResources.pending !== null
            label: Tr.tr("settings.imports.confirm")
            description: !ServiceResources.pending ? ""
                : ServiceResources.pending.kind === "greeter" ? Tr.tr("settings.imports.confirmGreeter")
                : ServiceResources.pending.kind === "wallpapers" ? Tr.tr("settings.imports.confirmWallpapers").arg(ServiceUpdate.pretty(ServiceResources.pending.destination))
                : Tr.tr("settings.imports.confirmConfig").arg(ServiceUpdate.pretty(ServiceResources.pending.destination))
            Row
            {
                spacing: 8
                SettingsButton { text: Tr.tr("common.cancel"); onClicked: ServiceResources.pending = null }
                SettingsButton
                {
                    objectName: "applyResourceImport"
                    text: ServiceResources.pending && ServiceResources.pending.kind === "wallpapers" ? Tr.tr("settings.imports.import") : Tr.tr("settings.dependencies.continueInTerminal")
                    enabled: !ServiceResources.busy && !ServiceUpdate.busy
                    onClicked: ServiceResources.apply()
                }
            }
        }
        Repeater
        {
            model: ServiceResources.entries
            SettingsRow
            {
                id: resourceRow
                required property var modelData
                label: resourceRow.modelData.kind === "dots" ? resourceRow.modelData.name : resourceRow.modelData.kind === "wallpapers" ? Tr.tr("common.wallpapers") : Tr.tr("settings.imports.greeter")
                description: resourceRow.modelData.kind === "greeter" ? Tr.tr("settings.imports.greeterHint")
                    : (resourceRow.modelData.kind === "wallpapers" ? Tr.tr("settings.imports.wallpapersHint") : Tr.tr("settings.imports.configHint")).arg(ServiceUpdate.pretty(resourceRow.modelData.destination))
                SettingsButton
                {
                    objectName: "importResource-" + resourceRow.modelData.id
                    text: ServiceResources.operation === resourceRow.modelData.id ? Tr.tr("common.working") : Tr.tr("settings.imports.import")
                    enabled: !ServiceResources.busy && !ServiceUpdate.busy && ServiceResources.pending === null
                    onClicked: ServiceResources.request(resourceRow.modelData.id)
                }
            }
        }
    }

    SettingsDisclosure
    {
        title: Tr.tr("settings.dependencies.title")
        icon: Icon.settingsApplications
        summary: ServiceDependencies.entries.length > 0
            ? ServiceDependencies.entries.filter(entry => entry.installed).length + " / " + ServiceDependencies.entries.length : ""
        description: Tr.tr("settings.dependencies.description")
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
        SettingsRow
        {
            visible: ServiceDependencies.pending !== null
            label: Tr.tr("settings.dependencies.confirm")
            description: ServiceDependencies.pending
                ? (ServiceDependencies.pending.remove ? Tr.tr("settings.dependencies.confirmRemove") : Tr.tr("settings.dependencies.confirmInstall")).arg(ServiceDependencies.pending.tool) : ""
            Row
            {
                spacing: 8
                SettingsButton { text: Tr.tr("common.cancel"); onClicked: ServiceDependencies.pending = null }
                SettingsButton { text: Tr.tr("settings.dependencies.continueInTerminal"); onClicked: ServiceDependencies.apply(); enabled: !ServiceDependencies.busy }
            }
        }
        SettingsRow
        {
            visible: ServiceDependencies.busy && ServiceDependencies.entries.length === 0
            label: Tr.tr("common.checking")
        }
        Repeater
        {
            model: ServiceDependencies.entries
            SettingsRow
            {
                id: dependencyRow
                required property var modelData
                label: dependencyRow.modelData.tool
                description: (dependencyRow.modelData.required ? Tr.tr("settings.dependencies.required") : Tr.tr("settings.dependencies.optional"))
                    + (dependencyRow.modelData.packages.length ? " · " + dependencyRow.modelData.packages.join(", ") : "")
                valueText: dependencyRow.modelData.installed ? Tr.tr("common.installed") : Tr.tr("common.notInstalled")
                SettingsButton
                {
                    visible: !dependencyRow.modelData.installed || dependencyRow.modelData.removable
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

    readonly property var notes: ServiceUpdate.availableUpdate ? ServiceUpdate.pending
        : ServiceUpdate.currentRelease ? [ServiceUpdate.currentRelease] : []

    SettingsGroup
    {
        visible: pageUpdates.notes.length > 0
        title: ServiceUpdate.availableUpdate ? Tr.tr("common.whatsNew") : Tr.tr("settings.updates.thisVersion")

        Repeater
        {
            model: pageUpdates.notes

            ReleaseNotes
            {
                required property var modelData

                release: modelData
            }
        }
    }

    component Chip: Rectangle
    {
        property string text: ""
        property color  tint: "transparent"
        readonly property bool tinted: tint.a > 0

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: chipText.implicitWidth + 14
        height: chipText.implicitHeight + 6
        radius: height / 2
        color: tinted ? Qt.rgba(tint.r, tint.g, tint.b, 0.16) : Theme.colorField

        ShellText
        {
            id: chipText
            anchors.centerIn: parent
            label: parent.text
            size: 10
            color: parent.tinted ? parent.tint : Theme.text2
        }
    }

    component ReleaseNotes: Item
    {
        id: notesItem

        property var  release
        property bool expanded: false

        readonly property real collapsedHeight: 180
        readonly property bool tall: body.implicitHeight > collapsedHeight + 40

        width: parent ? parent.width : 400
        height: column.implicitHeight + 32

        SettingsTile { row: notesItem }

        Column
        {
            id: column

            x: 18
            y: 16
            width: parent.width - 36
            spacing: 10

            Item
            {
                width: parent.width
                height: Math.max(heading.implicitHeight, github.height)

                Row
                {
                    id: heading

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    ShellText
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        label: notesItem.release.name
                        size: 14
                        color: Theme.text1
                        font.bold: true
                    }
                    Chip { visible: notesItem.release.prerelease; text: Tr.tr("settings.updates.preRelease"); tint: Theme.colorWarning }
                    ShellText
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        label: pageUpdates.date(notesItem.release.date)
                        size: 11
                        color: Theme.text3
                    }
                }

                SettingsButton
                {
                    id: github

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: notesItem.release.url !== ""
                    text: Tr.tr("settings.updates.viewOnGithub")
                    onClicked: Qt.openUrlExternally(notesItem.release.url)
                }
            }

            Item
            {
                width: parent.width
                height: notesItem.tall && !notesItem.expanded ? notesItem.collapsedHeight : body.implicitHeight
                clip: true
                Glide on height {}

                Text
                {
                    id: body

                    width: parent.width
                    text: notesItem.release.notes !== "" ? notesItem.release.notes : "_" + Tr.tr("settings.updates.noReleaseNotes") + "_"
                    textFormat: Text.MarkdownText
                    wrapMode: Text.Wrap
                    color: Theme.text2
                    linkColor: Theme.colorAttention
                    font.pixelSize: Math.round(12 * Config.themeScale)
                    font.family: Theme.fontText
                    lineHeight: 1.15
                    onLinkActivated: link => Qt.openUrlExternally(link)

                    HoverHandler { cursorShape: body.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor }
                }

                Rectangle
                {
                    visible: notesItem.tall && !notesItem.expanded
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 48
                    gradient: Gradient
                    {
                        GradientStop { position: 0; color: Qt.rgba(Theme.settingsColorCard.r, Theme.settingsColorCard.g, Theme.settingsColorCard.b, 0) }
                        GradientStop { position: 1; color: Theme.settingsColorCard }
                    }
                }
            }

            SettingsButton
            {
                visible: notesItem.tall
                text: notesItem.expanded ? Tr.tr("settings.updates.showLess") : Tr.tr("settings.updates.showMore")
                icon: notesItem.expanded ? Icon.chevronUp : Icon.chevronDown
                onClicked: notesItem.expanded = !notesItem.expanded
            }
        }
    }
}
