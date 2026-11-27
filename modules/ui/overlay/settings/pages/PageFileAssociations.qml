import QtQuick

import "../../../../core"
import "../components"

SettingsPage
{
    title: Tr.tr("settings.fileAssociations.title")
    subtitle: Tr.tr("settings.fileAssociations.description")

    SettingsFileAssociations {}
}
