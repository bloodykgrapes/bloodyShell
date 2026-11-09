import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageTimeLanguage

    title: Tr.tr("common.timeLanguage")
    subtitle: Tr.tr("settings.timeLanguage.description")

    property date now: new Date()
    Timer { interval: 30000; running: pageTimeLanguage.active; repeat: true; onTriggered: pageTimeLanguage.now = new Date() }

    Component.onCompleted: { ServiceKeyboard.refresh(); ServiceRegion.refresh() }

    property string newLayout: ""
    property string newVariant: ""
    readonly property var newVariants: [{ label: Tr.tr("common.default"), value: "" }].concat((ServiceKeyboard.variants[newLayout] || []).map(v => ({ label: v.name, value: v.code })))

    SettingsGroup
    {
        title: Tr.tr("settings.timeLanguage.dateAndTime")
        subtitle: Tr.tr("settings.timeLanguage.authorizationHint")

        SettingsRow
        {
            visible: ServiceRegion.error !== ""
            label: Tr.tr("settings.timeLanguage.applyFailed")
            badge: Tr.tr("common.error")
            badgeColor: Theme.colorCritical
            description: ServiceRegion.error
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.timeZone")
            description: Qt.formatDateTime(pageTimeLanguage.now, Config.barWidgetClock24 ? "HH:mm" : "h:mm AP") + " · " + Qt.formatDateTime(pageTimeLanguage.now, "t")

            SettingsCombo
            {
                width: 300
                enabled: !ServiceRegion.busy
                options: ServiceRegion.timezones.map(z => ({ label: z.replace(/_/g, " "), value: z }))
                current: ServiceRegion.timezone
                placeholderText: ServiceRegion.timezone || Tr.tr("common.loading")
                onSelected: value => ServiceRegion.setTimezone(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.autoTime")
            description: Tr.tr("settings.timeLanguage.timeSyncHint")
            enabled: ServiceRegion.canNtp && !ServiceRegion.busy

            Toggle { checked: ServiceRegion.ntp; onToggled: value => ServiceRegion.setNtp(value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.clock24Hour")
            Toggle { checked: Config.barWidgetClock24; onToggled: value => Config.set("barWidgetClock24", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.clockSeconds")
            Toggle { checked: Config.barWidgetClockSeconds; onToggled: value => Config.set("barWidgetClockSeconds", value) }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.timeLanguage.language")

        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.shellLanguage")
            description: Tr.tr("settings.timeLanguage.shellLanguageHint")

            SettingsCombo
            {
                width: 300
                options: [{ label: Tr.tr("settings.timeLanguage.system").arg((Tr.languages.find(l => l.code === Tr.systemLanguage) || { name: "" }).name), value: "system" }]
                    .concat(Tr.languages.map(l => ({ label: l.name === l.english ? l.name : l.name + " — " + l.english, value: l.code })))
                current: Config.shellLanguage
                onSelected: value => Config.set("shellLanguage", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.systemLanguage")
            description: ServiceRegion.notice !== "" ? ServiceRegion.notice
                : Tr.tr("settings.timeLanguage.systemLanguageHint")

            SettingsCombo
            {
                width: 300
                enabled: !ServiceRegion.busy
                options: ServiceRegion.locales.map(l => ({ label: l, value: l }))
                current: ServiceRegion.locale
                placeholderText: ServiceRegion.locale || Tr.tr("common.loading")
                onSelected: value => ServiceRegion.setLocale(value)
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.timeLanguage.keyboardLayouts")
        subtitle: Tr.tr("settings.timeLanguage.layoutsHint")

        SettingsRow
        {
            visible: ServiceKeyboard.error !== ""
            label: Tr.tr("settings.display.saveFailed")
            badge: Tr.tr("common.error")
            badgeColor: Theme.colorCritical
            description: ServiceKeyboard.error
        }

        Repeater
        {
            model: ServiceKeyboard.layouts

            SettingsRow
            {
                id: layoutRow

                required property var modelData
                required property int index

                readonly property bool isCurrent: index === ServiceCompositor.keyboardLayoutIndex

                label: ServiceKeyboard.title(modelData)
                description: modelData.layout + (modelData.variant ? " · " + modelData.variant : "") + (index === 0 ? " · default" : "") + (isCurrent ? " · current" : "")

                Row
                {
                    spacing: 6

                    SettingsButton
                    {
                        text: layoutRow.isCurrent ? Tr.tr("settings.timeLanguage.active") : Tr.tr("settings.timeLanguage.switch")
                        icon: layoutRow.isCurrent ? Icon.check : ""
                        enabled: !layoutRow.isCurrent
                        onClicked: ServiceCompositor.setKeyboardLayout(layoutRow.index)
                    }
                    SettingsIconButton { icon: Icon.chevronUp; enabled: layoutRow.index > 0; onClicked: ServiceKeyboard.moveLayout(layoutRow.index, -1) }
                    SettingsIconButton { icon: Icon.chevronDown; enabled: layoutRow.index < ServiceKeyboard.layouts.length - 1; onClicked: ServiceKeyboard.moveLayout(layoutRow.index, 1) }
                    SettingsIconButton { icon: Icon.close; enabled: ServiceKeyboard.layouts.length > 1; onClicked: ServiceKeyboard.removeLayout(layoutRow.index) }
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.addLayout")
            stacked: true

            Row
            {
                spacing: 8

                SettingsCombo
                {
                    width: 260
                    placeholderText: Tr.tr("settings.compositor.layout")
                    options: ServiceKeyboard.catalog.map(l => ({ label: l.name, value: l.code }))
                    current: pageTimeLanguage.newLayout
                    onSelected: value => { pageTimeLanguage.newLayout = value; pageTimeLanguage.newVariant = "" }
                }
                SettingsCombo
                {
                    width: 260
                    enabled: pageTimeLanguage.newLayout !== "" && pageTimeLanguage.newVariants.length > 1
                    options: pageTimeLanguage.newVariants
                    current: pageTimeLanguage.newVariant
                    onSelected: value => pageTimeLanguage.newVariant = value
                }
                SettingsButton
                {
                    text: Tr.tr("common.add")
                    icon: Icon.add
                    enabled: pageTimeLanguage.newLayout !== ""
                    onClicked: { ServiceKeyboard.addLayout(pageTimeLanguage.newLayout, pageTimeLanguage.newVariant); pageTimeLanguage.newLayout = ""; pageTimeLanguage.newVariant = "" }
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.layoutShortcut")

            SettingsCombo
            {
                width: 260
                options:
                [
                    { label: Tr.tr("settings.timeLanguage.superSpace"), value: "grp:win_space_toggle" },
                    { label: Tr.tr("settings.timeLanguage.altShift"),   value: "grp:alt_shift_toggle" },
                    { label: Tr.tr("settings.timeLanguage.ctrlShift"),  value: "grp:ctrl_shift_toggle" },
                    { label: Tr.tr("settings.timeLanguage.altSpace"),   value: "grp:alt_space_toggle" },
                    { label: Tr.tr("settings.timeLanguage.ctrlSpace"),  value: "grp:ctrl_space_toggle" },
                    { label: Tr.tr("settings.timeLanguage.capsLock"),     value: "grp:caps_toggle" },
                    { label: Tr.tr("settings.timeLanguage.bothShifts"),   value: "grp:shifts_toggle" },
                    { label: Tr.tr("settings.timeLanguage.rightAlt"),     value: "grp:toggle" },
                    { label: Tr.tr("common.none"),          value: "" },
                ]
                current: ServiceKeyboard.switchOption
                onSelected: value => ServiceKeyboard.set("switchOption", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.numLock")
            Toggle { checked: ServiceKeyboard.numlock; onToggled: value => ServiceKeyboard.set("numlock", value) }
        }
    }
}
