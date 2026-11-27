pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"

SettingsRowGroup
{
    id: plymouth

    required property bool active
    property string stagedTheme: ""
    readonly property var snapshot: ServicePlymouth.state
    readonly property string selectedTheme: stagedTheme || snapshot.current
    readonly property string currentName: snapshot.themes.find(entry => entry.id === snapshot.current)?.name || snapshot.current
    readonly property bool hasThemes: snapshot.themes.length > 0

    signal revealRequested(Item item)

    title: Tr.tr("settings.plymouth.theme")

    onActiveChanged:
    {
        if (active) ServicePlymouth.refresh();
        else stagedTheme = "";
    }
    onSnapshotChanged:
    {
        if (stagedTheme && (stagedTheme === snapshot.current || !snapshot.themes.some(entry => entry.id === stagedTheme)))
            stagedTheme = "";
    }
    Component.onCompleted: if (active) ServicePlymouth.refresh()

    SettingsRow
    {
        visible: ServicePlymouth.scanned && !plymouth.snapshot.installed
        label: Tr.tr("common.notInstalled")
        description: Tr.tr("settings.plymouth.installHint")
        Button
        {
            text: Tr.tr("common.updates")
            onClicked: OverlayState.settingsPage = Registry.settings.findIndex(page => page.id === "hub")
        }
    }

    SettingsRow
    {
        visible: plymouth.snapshot.installed
        label: Tr.tr("settings.plymouth.theme")
        description: [
            plymouth.currentName ? Tr.tr("settings.plymouth.current").arg(plymouth.currentName) : "",
            !plymouth.hasThemes ? Tr.tr("settings.plymouth.noThemes")
                : ServicePlymouth.applied ? Tr.tr("settings.plymouth.applied")
                : !plymouth.snapshot.canApply ? Tr.tr("settings.plymouth.authMissing") : ""
        ].filter(text => text !== "").join(" · ")
        stacked: plymouth.hasThemes
        Grid
        {
            id: themes
            visible: plymouth.hasThemes
            width: parent.width
            spacing: 10
            columns: Math.max(1, Math.min(3, plymouth.snapshot.themes.length, Math.floor((width + spacing) / (176 + spacing))))

            Repeater
            {
                model: plymouth.snapshot.themes

                PlymouthThemeCard
                {
                    required property var modelData

                    width: Math.max(0, Math.min(248, (themes.width - (themes.columns - 1) * themes.spacing) / themes.columns))
                    theme: modelData
                    current: plymouth.snapshot.current === modelData.id
                    selected: plymouth.selectedTheme === modelData.id
                    loadArtwork: plymouth.active
                    busy: ServicePlymouth.busy
                    applying: ServicePlymouth.applying
                    canApply: plymouth.snapshot.canApply
                    needsApply: !current || ServicePlymouth.failedTheme === modelData.id
                    error: selected && ServicePlymouth.failedTheme === modelData.id ? ServicePlymouth.applyError : ""

                    onSelectedTheme: plymouth.stagedTheme = current ? "" : modelData.id
                    onApplyRequested: ServicePlymouth.apply(modelData.id)
                    onRevealRequested: action => plymouth.revealRequested(action)
                }
            }
        }
    }

    SettingsRow
    {
        visible: ServicePlymouth.readError !== ""
        label: Tr.tr("common.actionFailed")
        description: ServicePlymouth.readError
        Button
        {
            text: Tr.tr("common.refresh")
            enabled: !ServicePlymouth.busy
            onClicked: ServicePlymouth.refresh()
        }
    }
}
