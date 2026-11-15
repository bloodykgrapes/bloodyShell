import QtQuick

import "../../../core"
import "../../../services"
import "../settings/components"

Column
{
    width: parent ? parent.width : 600
    spacing: 2
    Component.onCompleted: ServiceRegion.refresh()

    SettingsRow
    {
        visible: ServiceRegion.error !== ""
        label: Tr.tr("settings.timeLanguage.applyFailed")
        description: ServiceRegion.error
    }
    SettingsRow
    {
        label: Tr.tr("settings.timeLanguage.shellLanguage")
        SettingsCombo
        {
            objectName: "helperShellLanguage"
            preferredWidth: 300
            options: [{label: Tr.tr("settings.timeLanguage.system").arg((Tr.languages.find(language => language.code === Tr.systemLanguage) || {name: ""}).name), value: "system"}]
                .concat(Tr.languages.map(language => ({label: language.name === language.english ? language.name : language.name + " — " + language.english, value: language.code})))
            current: Config.shellLanguage
            onSelected: value => Config.set("shellLanguage", value)
        }
    }
    SettingsRow
    {
        label: Tr.tr("settings.timeLanguage.systemLanguage")
        description: ServiceRegion.notice
        SettingsCombo
        {
            objectName: "helperSystemLanguage"
            preferredWidth: 300
            enabled: !ServiceRegion.busy
            options: ServiceRegion.locales.map(locale => ({label: locale, value: locale}))
            current: ServiceRegion.locale
            placeholderText: ServiceRegion.locale || Tr.tr("common.loading")
            onSelected: value => ServiceRegion.setLocale(value)
        }
    }
    SettingsRow
    {
        label: Tr.tr("settings.timeLanguage.timeZone")
        SettingsCombo
        {
            objectName: "helperTimezone"
            preferredWidth: 300
            enabled: !ServiceRegion.busy
            options: ServiceRegion.timezones.map(zone => ({label: zone.replace(/_/g, " "), value: zone}))
            current: ServiceRegion.timezone
            placeholderText: ServiceRegion.timezone || Tr.tr("common.loading")
            onSelected: value => ServiceRegion.setTimezone(value)
        }
    }
}
