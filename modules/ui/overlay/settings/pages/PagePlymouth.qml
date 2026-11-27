import QtQuick

import "../../../../core"
import "../components"

SettingsPage
{
    id: pagePlymouth

    title: "Plymouth"
    subtitle: Tr.tr("settings.plymouth.description")

    SettingsPlymouth
    {
        objectName: "plymouthSection"
        active: pagePlymouth.active
        onRevealRequested: item => pagePlymouth.revealItem(item)
    }
}
