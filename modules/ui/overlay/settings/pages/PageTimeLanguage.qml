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
    Timer
    {
        interval: 30000
        running: pageTimeLanguage.active
        repeat: true
        onTriggered: pageTimeLanguage.now = new Date()
    }

    Component.onCompleted: { ServiceKeyboard.refresh(); ServiceRegion.refresh() }

    onActiveChanged: if (!active && !OverlayState.popupsSuspended) layoutPicker.close()

    SettingsPopup
    {
        id: layoutPicker
        objectName: "keyboardLayoutPicker"
        host: pageTimeLanguage
        preferredWidth: 520
        property string layout: ""
        property string variant: ""
        readonly property var variants: [{ label: Tr.tr("common.default"), value: "" }].concat(
            (ServiceKeyboard.variants[layout] || []).map(v => ({ label: v.name, value: v.code })))
        readonly property bool canAdd: layout !== "" && !ServiceKeyboard.busy
            && !ServiceKeyboard.layouts.some(entry => entry.layout === layout && entry.variant === variant)
        onAboutToShow: { layout = ""; variant = ""; }
        panelContent: SettingsPopupLayout
        {
            anchors.fill: parent
            title: Tr.tr("settings.timeLanguage.addLayout")
            icon: Icon.keyboard
            showCloseButton: true
            onCloseRequested: layoutPicker.close()
            SettingsRow
            {
                width: parent.width
                label: Tr.tr("common.keyboardLayout")
                stacked: true
                SettingsDropdown
                {
                    objectName: "newKeyboardLayout"
                    width: parent.width
                    placeholderText: Tr.tr("common.keyboardLayout")
                    options: ServiceKeyboard.catalog.map(entry => ({ label: entry.name, value: entry.code }))
                    current: layoutPicker.layout
                    onSelected: value => { layoutPicker.layout = value; layoutPicker.variant = ""; }
                }
            }
            SettingsRow
            {
                width: parent.width
                label: Tr.tr("settings.timeLanguage.variant")
                stacked: true
                SettingsDropdown
                {
                    objectName: "newKeyboardVariant"
                    width: parent.width
                    enabled: layoutPicker.layout !== "" && layoutPicker.variants.length > 1
                    options: layoutPicker.variants
                    current: layoutPicker.variant
                    onSelected: value => layoutPicker.variant = value
                }
            }
            actions: [
                Button { text: Tr.tr("common.cancel"); onClicked: layoutPicker.close() },
                Button
                {
                    objectName: "confirmKeyboardLayout"
                    text: Tr.tr("common.add")
                    primary: true
                    enabled: layoutPicker.canAdd
                    onClicked:
                    {
                        ServiceKeyboard.addLayout(layoutPicker.layout, layoutPicker.variant);
                        layoutPicker.close();
                    }
                }
            ]
        }
    }

    SettingsRowGroup
    {
        objectName: "languageSettings"
        title: Tr.tr("settings.timeLanguage.language")

        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.systemLanguage")
            description: ServiceRegion.notice !== "" ? ServiceRegion.notice
                : Tr.tr("settings.timeLanguage.systemLanguageHint")

            SettingsDropdown
            {
                preferredWidth: 300
                enabled: !ServiceRegion.busy
                options: ServiceRegion.locales.map(l => ({ label: l, value: l }))
                current: ServiceRegion.locale
                placeholderText: ServiceRegion.locale || Tr.tr("common.loading")
                onSelected: value => ServiceRegion.setLocale(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.shellLanguage")
            description: Tr.tr("settings.timeLanguage.shellLanguageHint")

            SettingsDropdown
            {
                preferredWidth: 300
                options: [{ label: Tr.tr("settings.timeLanguage.system").arg((Tr.languages.find(l => l.code === Tr.systemLanguage) || { name: "" }).name), value: "system" }]
                    .concat(Tr.languages.map(l => ({ label: l.name === l.english ? l.name : l.name + " — " + l.english, value: l.code })))
                current: Config.shellLanguage
                onSelected: value => Config.set("shellLanguage", value)
            }
        }
    }

    SettingsRowGroup
    {
        objectName: "dateTimeSettings"
        title: Tr.tr("settings.timeLanguage.dateAndTime")

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

            SettingsDropdown
            {
                preferredWidth: 300
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

    SettingsRowGroup
    {
        objectName: "keyboardSettings"
        title: Tr.tr("settings.timeLanguage.keyboard")
        visible: ServiceCompositor.supports("keyboard")

        SettingsRow
        {
            visible: ServiceKeyboard.error !== ""
            label: Tr.tr("settings.display.saveFailed")
            badge: Tr.tr("common.error")
            badgeColor: Theme.colorCritical
            description: ServiceKeyboard.error
        }

        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.layoutShortcut")

            SettingsDropdown
            {
                preferredWidth: 260
                options: Registry.layoutShortcutOptions
                current: ServiceKeyboard.switchOption
                onSelected: value => ServiceKeyboard.set("switchOption", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.timeLanguage.addLayout")
            Button
            {
                objectName: "addKeyboardLayout"
                text: Tr.tr("common.add")
                icon: Icon.add
                enabled: !ServiceKeyboard.busy && ServiceKeyboard.catalog.length > 0
                onClicked: layoutPicker.open()
            }
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

                    Button
                    {
                        text: layoutRow.isCurrent ? Tr.tr("settings.timeLanguage.active") : Tr.tr("settings.timeLanguage.switch")
                        icon: layoutRow.isCurrent ? Icon.check : ""
                        enabled: !layoutRow.isCurrent
                        onClicked: ServiceCompositor.setKeyboardLayout(layoutRow.index)
                    }
                    Button { iconOnly: true; icon: Icon.chevronUp; enabled: layoutRow.index > 0; onClicked: ServiceKeyboard.moveLayout(layoutRow.index, -1) }
                    Button { iconOnly: true; icon: Icon.chevronDown; enabled: layoutRow.index < ServiceKeyboard.layouts.length - 1; onClicked: ServiceKeyboard.moveLayout(layoutRow.index, 1) }
                    Button { iconOnly: true; icon: Icon.close; enabled: ServiceKeyboard.layouts.length > 1; onClicked: ServiceKeyboard.removeLayout(layoutRow.index) }
                }
            }
        }
    }
}
