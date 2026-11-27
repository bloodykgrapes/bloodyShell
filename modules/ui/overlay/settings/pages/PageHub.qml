pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageHub
    title: Tr.tr("settings.structure.hub")
    Component.onDestruction: { ServiceDependencies.pending = null; ServiceResources.pending = null; }

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
        host: pageHub
        visible: pageHub.active && ServiceResources.pending !== null
        title: clearing ? Tr.tr("settings.imports.clear") + " · " + pageHub.resourceTitle(resource)
            : Tr.tr(direct ? "settings.structure.download" : "settings.imports.confirm") + " · " + pageHub.resourceTitle(resource)
        description: !ServiceResources.pending ? ""
            : clearing ? Tr.tr("settings.imports.confirmClearGreeter")
            : ServiceResources.pending.kind === "greeter" ? Tr.tr("settings.imports.confirmGreeter")
            : ServiceResources.pending.kind === "compositor" ? Tr.tr("settings.imports.confirmNiri").arg(ServiceUpdate.pretty(ServiceResources.pending.destination))
            : ServiceResources.pending.kind === "dots" ? Tr.tr("settings.imports.confirmDots").arg((ServiceResources.pending.programs || []).join(", "))
            : Tr.tr("settings.imports.confirmWallpapers").arg(ServiceUpdate.pretty(ServiceResources.pending.destination))
        errorText: ServiceResources.error
        acceptText: direct ? Tr.tr("settings.structure.download") : Tr.tr("settings.dependencies.continueInTerminal")
        danger: clearing
        acceptEnabled: !ServiceResources.busy && !ServiceUpdate.busy
        onAccepted: ServiceResources.apply()
        onRejected: ServiceResources.pending = null
    }

    SettingsConfirmation
    {
        objectName: "dependencyConfirmation"
        host: pageHub
        visible: pageHub.active && ServiceDependencies.pending !== null
        title: Tr.tr("settings.dependencies.confirm")
        description: ServiceDependencies.pending
            ? (ServiceDependencies.pending.remove ? Tr.tr("settings.dependencies.confirmRemove") : Tr.tr("settings.dependencies.confirmInstall")).arg(ServiceDependencies.pending.name) : ""
        errorText: ServiceDependencies.actionError
        acceptText: Tr.tr("settings.dependencies.continueInTerminal")
        acceptEnabled: ServiceDependencies.pending !== null && !ServiceDependencies.checking(ServiceDependencies.pending.required) && ServiceDependencies.operation === ""
        danger: ServiceDependencies.pending !== null && ServiceDependencies.pending.remove
        onAccepted: ServiceDependencies.apply()
        onRejected: ServiceDependencies.pending = null
    }

    ResourceList { objectName: "resourceImports"; download: false }

    ResourceList { objectName: "resourceDownloads"; download: true }

    component ResourceList: SettingsRowGroup
    {
        required property bool download
        title: Tr.tr(download ? "settings.structure.download" : "settings.structure.import")
        summary: ServiceResources.busy ? Tr.tr("common.working") : ""
        Component.onCompleted: ServiceResources.refresh()

        SettingsRow
        {
            visible: ServiceResources.error !== ""
            label: Tr.tr("common.error")
            description: ServiceResources.error
            Button
            {
                text: Tr.tr("common.refresh")
                enabled: !ServiceResources.busy && !ServiceUpdate.busy && ServiceResources.pending === null
                onClicked: ServiceResources.refresh()
            }
        }
        Repeater
        {
            model: ServiceResources.entries.filter(entry => (entry.kind === "wallpapers") === download)
            SettingsRow
            {
                id: resourceRow
                required property var modelData
                objectName: "importRow-" + modelData.id
                label: pageHub.resourceTitle(modelData)
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
                    Button
                    {
                        objectName: "clearResource-" + resourceRow.modelData.id
                        visible: resourceRow.modelData.kind === "greeter"
                        text: ServiceResources.operation === resourceRow.modelData.id && ServiceResources.operationAction === "clear" ? Tr.tr("common.working") : Tr.tr("settings.imports.clear")
                        danger: true
                        enabled: resourceRow.modelData.installed === true && !ServiceResources.busy && !ServiceUpdate.busy && ServiceResources.pending === null
                        onClicked: ServiceResources.request(resourceRow.modelData.id, "clear")
                    }
                    Button
                    {
                        objectName: "importResource-" + resourceRow.modelData.id
                        text: ServiceResources.operation === resourceRow.modelData.id && ServiceResources.operationAction === "import" ? Tr.tr("common.working") : Tr.tr(download ? "settings.structure.download" : "settings.imports.import")
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
        objectName: "requiredDependencies"
        title: Tr.tr("settings.dependencies.title")
        description: Tr.tr("settings.dependencies.description")
        requiredPackages: true
    }

    PackageList
    {
        objectName: "optionalPackages"
        title: Tr.tr("settings.packages.title")
        description: Tr.tr("settings.packages.description")
        requiredPackages: false
    }

    component PackageList: SettingsRowGroup
    {
        id: packageList

        required property bool requiredPackages
        readonly property var entries: requiredPackages ? ServiceDependencies.dependencies
            : ServiceDependencies.packages

        readonly property bool checking: ServiceDependencies.checking(requiredPackages)
        readonly property string error: ServiceDependencies.listError(requiredPackages)

        summary: checking ? Tr.tr("common.checking")
            : entries.length > 0 ? entries.filter(entry => entry.installed).length + " / " + entries.length : ""
        Component.onCompleted: ServiceDependencies.refresh(requiredPackages)

        SettingsRow
        {
            visible: packageList.error !== ""
            label: Tr.tr("settings.dependencies.error")
            description: packageList.error
            Button { text: Tr.tr("common.refresh"); onClicked: ServiceDependencies.refresh(packageList.requiredPackages); enabled: !packageList.checking && ServiceDependencies.operation === "" }
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
                Button
                {
                    objectName: "packageAction-" + dependencyRow.modelData.tool
                    visible: !dependencyRow.modelData.installed || (!packageList.requiredPackages && dependencyRow.modelData.removable)
                    text: ServiceDependencies.operation === dependencyRow.modelData.tool ? Tr.tr("common.working")
                        : !dependencyRow.modelData.supported ? Tr.tr("settings.dependencies.manual")
                        : dependencyRow.modelData.installed ? Tr.tr("common.remove") : Tr.tr("common.install")
                    danger: dependencyRow.modelData.installed
                    enabled: dependencyRow.modelData.supported && !packageList.checking && ServiceDependencies.operation === "" && ServiceDependencies.pending === null
                    onClicked: ServiceDependencies.request(dependencyRow.modelData.tool, dependencyRow.modelData.installed)
                }
            }
        }
    }
}
