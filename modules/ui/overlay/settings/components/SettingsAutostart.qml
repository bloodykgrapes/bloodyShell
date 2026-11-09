pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"

SettingsDisclosure
{
    id: autostart

    title: Tr.tr("settings.autostart.title")
    description: Tr.tr("settings.autostart.description")
    icon: Icon.computerReboot
    summary: String(ServiceApplications.autostartEntries.length)

    property bool adding: false
    property string query: ""
    readonly property var candidates: ServiceApplications.search(query).filter(app => !ServiceApplications.hasAutostart(app.id)).slice(0, 4)

    function stateText(entry)
    {
        const label = Tr.tr(entry.enabled ? "settings.autostart.enabled" : "settings.autostart.disabled");
        const reasons = {
            invalid: "settings.autostart.invalid",
            desktop: "settings.autostart.otherDesktop",
            executable: "settings.autostart.missingExecutable",
            session: "settings.autostart.excluded"
        };
        return reasons[entry.reason] ? label + " · " + Tr.tr(reasons[entry.reason]) : label;
    }

    SettingsRow
    {
        label: Tr.tr("settings.autostart.atLogin")
        description: Tr.tr("settings.autostart.changesHint")

        Row
        {
            spacing: 6
            SettingsButton
            {
                objectName: "autostartAdd"
                text: Tr.tr(autostart.adding ? "common.cancel" : "settings.autostart.addApplication")
                icon: autostart.adding ? Icon.close : Icon.add
                enabled: !ServiceApplications.autostartBusy
                onClicked:
                {
                    autostart.adding = !autostart.adding;
                    if (autostart.adding) Qt.callLater(() => search.grabFocus());
                }
            }
            SettingsIconButton
            {
                icon: Icon.reload
                enabled: !ServiceApplications.autostartBusy
                onClicked: ServiceApplications.refreshAutostart()
                Accessible.name: Tr.tr("settings.autostart.refresh")
            }
        }
    }

    Column
    {
        width: parent.width
        visible: autostart.adding
        spacing: 4

        SettingsRow
        {
            label: Tr.tr("common.search")
            stacked: true
            SettingsInput
            {
                id: search
                objectName: "autostartSearch"
                width: parent.width
                placeholderText: Tr.tr("settings.applications.searchPlaceholder")
                onTextEdited: value => autostart.query = value
            }
        }
        Column
        {
            id: results
            objectName: "autostartCandidates"
            width: parent.width

            Repeater
            {
                model: autostart.candidates

                delegate: SettingsRow
                {
                    id: candidate
                    required property var modelData
                    width: results.width
                    height: 56
                    icon: ServiceApplications.iconFor(modelData.id)
                    label: modelData.name
                    description: modelData.id

                    SettingsButton
                    {
                        objectName: "autostartChoose-" + candidate.modelData.id
                        text: Tr.tr("common.add")
                        icon: Icon.add
                        enabled: !ServiceApplications.autostartBusy
                        onClicked: if (ServiceApplications.addAutostart(candidate.modelData.id)) autostart.adding = false
                    }
                }
            }
        }
        SettingsRow
        {
            visible: autostart.candidates.length === 0
            label: Tr.tr("settings.applications.noMatches")
        }
    }

    SettingsRow
    {
        visible: ServiceApplications.autostartError !== ""
        label: Tr.tr("common.error")
        description: ServiceApplications.autostartError
    }
    SettingsRow
    {
        visible: ServiceApplications.autostartSession === "inactive" || ServiceApplications.autostartSession === "unavailable"
        label: Tr.tr("settings.autostart.sessionUnavailable")
        description: Tr.tr("settings.autostart.sessionHint")
    }
    Repeater
    {
        model: ServiceApplications.autostartEntries

        SettingsRow
        {
            id: entry
            required property var modelData
            icon: ServiceApplications.iconSource(modelData.icon)
            label: modelData.name
            description: autostart.stateText(modelData)
            badge: modelData.system ? Tr.tr("settings.autostart.system") : ""

            Row
            {
                spacing: 10
                height: 32
                SettingsButton
                {
                    objectName: "autostartRemove-" + entry.modelData.id
                    visible: entry.modelData.removable
                    text: Tr.tr("common.remove")
                    icon: Icon.close
                    enabled: !ServiceApplications.autostartBusy
                    onClicked: ServiceApplications.removeAutostart(entry.modelData.id)
                }
                Toggle
                {
                    objectName: "autostartToggle-" + entry.modelData.id
                    anchors.verticalCenter: parent.verticalCenter
                    checked: entry.modelData.enabled
                    enabled: entry.modelData.valid && !ServiceApplications.autostartBusy
                    onToggled: value => ServiceApplications.setAutostartEnabled(entry.modelData.id, value)
                    Accessible.name: entry.modelData.name
                }
            }
        }
    }
    SettingsRow
    {
        visible: ServiceApplications.autostartEntries.length === 0 && !ServiceApplications.autostartBusy
        label: Tr.tr("settings.autostart.empty")
    }
}
