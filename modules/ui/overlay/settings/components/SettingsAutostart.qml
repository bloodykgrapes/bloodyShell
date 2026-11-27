pragma ComponentBehavior: Bound

import QtQuick
import "../../../../common"
import "../../../../core"
import "../../../../services"

SettingsRowGroup
{
    id: autostart

    title: Tr.tr("settings.autostart.title")

    readonly property var entries: ServiceApplications.autostartEntries.filter(entry => !entry.system)

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
        visible: ServiceApplications.autostartError !== ""
        label: Tr.tr("common.error")
        description: ServiceApplications.autostartError
    }
    Repeater
    {
        model: autostart.entries

        SettingsRow
        {
            id: entry
            required property var modelData
            icon: ServiceApplications.iconSource(modelData.icon)
            label: modelData.name
            description: autostart.stateText(modelData)

            Row
            {
                spacing: 10
                height: 32
                Button
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
        visible: autostart.entries.length === 0 && !ServiceApplications.autostartBusy
        label: Tr.tr("settings.autostart.empty")
    }
}
