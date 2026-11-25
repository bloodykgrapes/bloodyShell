pragma ComponentBehavior: Bound

import QtQuick
import "../../../../core"

SettingsRow
{
    id: row
    required property var entry
    property bool busy: false
    signal selected(string appId)

    label: entry.name || Tr.tr("settings.fileAssociations." + entry.id)
    description: entry.extensions
    SettingsDropdown
    {
        objectName: "fileAssociation-" + row.entry.id
        preferredWidth: 300
        options: row.entry.applications.map(app => ({label: app.name, value: app.id}))
        current: row.entry.current
        enabled: !row.busy && options.length > 0
        placeholderText: Tr.tr(options.length > 0 ? "settings.select" : "settings.defaultApplications.noApplications")
        onSelected: value => row.selected(value)
    }
}
