import QtQuick

import "../../../../core"
import "../components"

SettingsPage
{
    id: pageEasyEffects

    title: "Easy Effects"
    subtitle: Tr.tr("settings.easyEffects.description")

    SettingsEasyEffects
    {
        objectName: "easyEffectsSection"
        active: pageEasyEffects.active
    }
}
