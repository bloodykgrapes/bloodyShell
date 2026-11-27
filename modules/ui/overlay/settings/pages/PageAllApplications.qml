import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageAllApplications

    title: Tr.tr("settings.applications.all")

    property string query: ""
    readonly property var apps: ServiceApplications.search(query.trim().toLocaleLowerCase())

    onActiveChanged:
    {
        ServiceApplications.setAutostartActive(pageAllApplications, active);
        if (!active && !OverlayState.popupsSuspended)
        {
            applicationMenu.close();
            applicationRemoval.close();
        }
    }
    Component.onCompleted: ServiceApplications.setAutostartActive(pageAllApplications, active)
    Component.onDestruction: ServiceApplications.setAutostartActive(pageAllApplications, false)

    SettingsApplicationMenu
    {
        id: applicationMenu
        host: pageAllApplications
        onDeleteRequested: app => applicationRemoval.request(app)
    }
    SettingsApplicationRemoval
    {
        id: applicationRemoval
        host: pageAllApplications
    }

    header: SettingsInput
    {
        objectName: "applicationsSearch"
        width: parent.width
        icon: Icon.search
        clearable: true
        placeholderText: Tr.tr("settings.applications.searchPlaceholder")
        onTextEdited: value => pageAllApplications.query = value
    }

    SettingsRowGroup
    {
        id: applicationsList
        objectName: "applicationsList"
        title: Tr.tr("common.applications")
        summary: String(pageAllApplications.apps.length)

        Column
        {
            width: parent.width
            spacing: 1

            Repeater
            {
                model: pageAllApplications.apps

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
                visible: pageAllApplications.apps.length === 0
                label: Tr.tr("settings.applications.noMatches")
            }
        }
    }
}
