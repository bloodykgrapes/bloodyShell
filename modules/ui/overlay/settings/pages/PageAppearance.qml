pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageAppearance

    title: Tr.tr("common.appearance")
    subtitle: Tr.tr("settings.appearance.description")

    Component.onCompleted: ServiceAppearance.refresh()

    function withCurrent(list, current)
    {
        if (current === "" || list.indexOf(current) >= 0) return list.map(n => ({ label: n, value: n }));
        return [{ label: Tr.tr("settings.appearance.notInstalled").arg(current), value: current }].concat(list.map(n => ({ label: n, value: n })));
    }

    SettingsGroup
    {
        title: Tr.tr("common.shell")

        SettingsRow
        {
            label: Tr.tr("settings.appearance.theme")
            stacked: true

            SettingsStyleChoices
            {
                kind: "theme"
                options: Registry.themeOptions
                namePrefix: "themeStyle-"
                current: Config.themeStyle
                onSelected: value => Config.set("themeStyle", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.automaticColor")
            description: Tr.tr("settings.appearance.automaticColorHint")
            Toggle { checked: Config.themeAccent; onToggled: value => Config.set("themeAccent", value) }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.frameThickness")
            SettingsStepper
            {
                value: Theme.frameThickness
                from: 0; to: 8; step: 1; suffix: " px"
                onEdited: value => Config.set("frameThickness", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.animations")
            description: Tr.tr("settings.appearance.animationsHint")
            stacked: true

            SettingsStyleChoices
            {
                kind: "animation"
                options: Registry.animationOptions
                current: Config.themeAnimations
                onSelected: value => Config.set("themeAnimations", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.equalizerStyle")
            description: Tr.tr("settings.appearance.equalizerStyleHint")
            stacked: true

            SettingsStyleChoices
            {
                kind: "equalizer"
                options: Registry.equalizerOptions
                namePrefix: "equalizerStyle-"
                current: Config.equalizerStyle
                onSelected: value => Config.set("equalizerStyle", value)
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.appearance.wallpaper")

        SettingsRow
        {
            objectName: "currentWallpaperRow"
            label: Tr.tr("settings.appearance.currentWallpaper")
            stacked: true

            WallpaperPreview
            {
                objectName: "currentWallpaperPreview"
                width: parent.width
                height: implicitHeight
                onClicked: OverlayState.show("wallpapers")
            }
        }
        SettingsRow
        {
            id: directoryRow

            label: Tr.tr("settings.appearance.wallpaperFolder")
            stacked: true

            Row
            {
                width: parent.width
                spacing: 8

                SettingsInput
                {
                    id: directoryInput
                    width: parent.width
                    text: Config.wallpaperDirectory
                    placeholderText: "~/Pictures/Wallpapers"
                    onEditingFinished: if (text.trim() !== "") Config.set("wallpaperDirectory", text.trim())
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.wallpaperTransition")
            SettingsCombo
            {
                objectName: "wallpaperTransitionSelector"
                options: [
                    {label: Tr.tr("common.off"), value: "none"},
                    {label: Tr.tr("settings.appearance.wallpaperSimple"), value: "simple"},
                    {label: Tr.tr("settings.appearance.wallpaperFade"), value: "fade"},
                    {label: Tr.tr("settings.appearance.wallpaperLeft"), value: "left"},
                    {label: Tr.tr("settings.appearance.wallpaperRight"), value: "right"},
                    {label: Tr.tr("settings.appearance.wallpaperTop"), value: "top"},
                    {label: Tr.tr("settings.appearance.wallpaperBottom"), value: "bottom"},
                    {label: Tr.tr("settings.appearance.wallpaperWipe"), value: "wipe"},
                    {label: Tr.tr("settings.appearance.wallpaperWave"), value: "wave"},
                    {label: Tr.tr("settings.appearance.wallpaperGrow"), value: "grow"},
                    {label: Tr.tr("settings.appearance.wallpaperCenter"), value: "center"},
                    {label: Tr.tr("settings.appearance.wallpaperAny"), value: "any"},
                    {label: Tr.tr("settings.appearance.wallpaperShrink"), value: "outer"},
                    {label: Tr.tr("settings.appearance.wallpaperRandom"), value: "random"}
                ]
                current: Config.wallpaperTransition
                onSelected: value => Config.set("wallpaperTransition", value)
            }
        }
        ShellText
        {
            width: parent.width
            label: ServiceAppearance.wallpaperError
            color: Theme.colorCritical
            wrapMode: Text.Wrap
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.applications")
        enabled: ServiceAppearance.loaded

        SettingsRow
        {
            visible: ServiceAppearance.error !== ""
            label: Tr.tr("settings.appearance.applyFailed")
            badge: Tr.tr("common.error")
            badgeColor: Theme.colorCritical
            description: ServiceAppearance.error
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.iconTheme")
            SettingsCombo
            {
                options: pageAppearance.withCurrent(ServiceAppearance.iconThemes, ServiceAppearance.iconTheme)
                current: ServiceAppearance.iconTheme
                onSelected: value => ServiceAppearance.setIconTheme(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.cursorTheme")
            SettingsCombo
            {
                options: pageAppearance.withCurrent(ServiceAppearance.cursorThemes, ServiceAppearance.cursorTheme)
                current: ServiceAppearance.cursorTheme
                onSelected: value => ServiceAppearance.setCursorTheme(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.cursorSize")
            SettingsStepper
            {
                value: ServiceAppearance.cursorSize
                from: 16; to: 64; step: 2; suffix: " px"
                onEdited: value => ServiceAppearance.setCursorSize(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.fontFamily")
            SettingsCombo
            {
                options: pageAppearance.withCurrent(ServiceAppearance.fonts, ServiceAppearance.fontFamily)
                current: ServiceAppearance.fontFamily
                onSelected: value => ServiceAppearance.setFontFamily(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.fontSize")
            SettingsStepper
            {
                value: ServiceAppearance.fontSize
                from: 6; to: 24; step: 1; suffix: " pt"
                onEdited: value => ServiceAppearance.setFontSize(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.appTheme")
            SettingsButton { text: Tr.tr("settings.appearance.reapply"); icon: Icon.reload; enabled: !ServiceAppearance.busy; onClicked: ServiceAppearance.reapply() }
        }
    }
}
