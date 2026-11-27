pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageApplications

    title: Tr.tr("common.applications")
    subtitle: Tr.tr("settings.applications.description")

    onActiveChanged: ServiceApplications.setAutostartActive(pageApplications, active)
    Component.onCompleted: ServiceApplications.setAutostartActive(pageApplications, active)
    Component.onDestruction: ServiceApplications.setAutostartActive(pageApplications, false)

    SettingsRowGroup
    {
        Repeater
        {
            model: Registry.settings.filter(page => page.parent === "applications")

            SettingsRow
            {
                id: subpage
                required property var modelData
                icon: modelData.icon
                label: modelData.title

                Button
                {
                    objectName: "openApplicationPage-" + subpage.modelData.id
                    text: Tr.tr("common.open")
                    icon: Icon.chevronRight
                    radius: height / 2
                    onClicked: OverlayState.settingsPage = Registry.settingsIndex(subpage.modelData.id)
                }
            }
        }
    }

    SettingsDefaultApplications { objectName: "defaultApplicationsSection" }
    SettingsAutostart { objectName: "autostartSection" }
}
