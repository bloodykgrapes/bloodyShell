import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"
import "../components" as Parts

SettingsPage
{
    id: pageApplications

    title: Tr.tr("common.applications")
    subtitle: Tr.tr("settings.applications.description")

    property string query: ""
    readonly property var apps: ServiceApplications.search(query.trim().toLocaleLowerCase())

    onActiveChanged:
    {
        ServiceApplications.setAutostartActive(pageApplications, active);
        if (!active && !OverlayState.popupsSuspended)
        {
            applicationMenu.close();
            applicationRemoval.close();
        }
    }
    Component.onCompleted: ServiceApplications.setAutostartActive(pageApplications, active)
    Component.onDestruction: ServiceApplications.setAutostartActive(pageApplications, false)

    Parts.SettingsApplicationMenu
    {
        id: applicationMenu
        host: pageApplications
        onDeleteRequested: app => applicationRemoval.request(app)
    }
    Parts.SettingsApplicationRemoval
    {
        id: applicationRemoval
        host: pageApplications
    }

    SettingsAutostart { objectName: "autostartSection" }
    Parts.SettingsDefaultApplications { objectName: "defaultApplicationsSection" }
    Parts.SettingsFileAssociations {}

    SettingsRowGroup
    {
        id: applicationsList
        objectName: "applicationsList"
        title: Tr.tr("settings.applications.count").arg(pageApplications.apps.length)

        SettingsInput
        {
            objectName: "applicationsSearch"
            icon: Icon.search
            clearable: true
            x: 3
            width: Math.max(0, parent.width - 6)
            placeholderText: Tr.tr("settings.applications.searchPlaceholder")
            onTextEdited: value => pageApplications.query = value
        }
        Item { width: 1; height: 8 }

        Column
        {
            width: parent.width
            spacing: 1

            Repeater
            {
                model: pageApplications.apps

                SettingsRow
                {
                    id: appRow

                    required property var modelData

                    objectName: "applicationRow-" + modelData.id

                    icon: ServiceApplications.iconFor(modelData.id) || Icon.settingsApplications
                    label: modelData.name
                    description: modelData.id

                    TapHandler
                    {
                        parent: appRow
                        acceptedButtons: Qt.RightButton
                        onTapped: eventPoint => applicationMenu.openFor(appRow.modelData, appRow, eventPoint.position.x, eventPoint.position.y)
                    }

                    Row
                    {
                        spacing: 6

                        Button
                        {
                            id: menuButton
                            objectName: "applicationMenu-" + appRow.modelData.id
                            text: Tr.tr("settings.applications.actions")
                            icon: Icon.chevronDown
                            onClicked: applicationMenu.openFor(appRow.modelData, menuButton, 0, menuButton.height + 6)
                            Keys.onPressed: event =>
                            {
                                if (event.key !== Qt.Key_Menu && !(event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier)) return;
                                applicationMenu.openFor(appRow.modelData, menuButton, 0, menuButton.height + 6);
                                event.accepted = true;
                            }
                        }
                    }
                }
            }
            SettingsRow
            {
                visible: pageApplications.apps.length === 0
                label: Tr.tr("settings.applications.noMatches")
            }
        }
    }
}
