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

    Component.onCompleted:
    {
        ServiceAppearance.refresh();
        ServiceColors.refresh();
    }

    function withCurrent(list, current)
    {
        if (current === "" || list.indexOf(current) >= 0) return list.map(n => ({ label: n, value: n }));
        return [{ label: Tr.tr("settings.appearance.notInstalled").arg(current), value: current }].concat(list.map(n => ({ label: n, value: n })));
    }

    function schemeHint(style)
    {
        if (style === Enums.ThemeDark) return Tr.tr("settings.appearance.darkThemeHint");
        if (style === Enums.ThemeLight) return Tr.tr("settings.appearance.lightThemeHint");
        if (style === Enums.ThemeWallpaper) return Tr.tr("settings.appearance.wallpaperThemeHint");
        return Tr.tr("settings.appearance.autoThemeHint");
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.appearance.theme")

        SettingsRow
        {
            label: Tr.tr("settings.structure.scheme")
            description: pageAppearance.schemeHint(Config.themeStyle)
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
            label: Tr.tr("settings.appearance.accent")
            description: Tr.tr("settings.appearance.accentHint")

            SettingsChoices
            {
                objectName: "accentMode"
                options: Registry.accentModeOptions
                current: Config.themeAccentMode
                onSelected: value => Config.set("themeAccentMode", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.accentHue")
            visible: Config.themeAccentMode === Enums.AccentCustom

            SettingsSlider
            {
                objectName: "accentHue"
                from: 0
                to: 360
                step: 1
                hue: true
                value: Config.accentHue
                valueText: Math.round(shown) + "°"
                onMoved: value => Config.set("accentHue", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.highlight")
            stacked: true

            SettingsChoices
            {
                objectName: "highlightStyle"
                wrap: true
                options: Registry.highlightOptions
                current: Config.highlightStyle
                onSelected: value => Config.set("highlightStyle", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.highlightHue")
            visible: Config.highlightStyle === Enums.HighlightCustom

            SettingsSlider
            {
                objectName: "highlightHue"
                from: 0
                to: 360
                step: 1
                hue: true
                value: Config.highlightHue
                valueText: Math.round(shown) + "°"
                onMoved: value => Config.set("highlightHue", value)
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.motion")

        SettingsRow
        {
            label: Tr.tr("settings.structure.reduceMotion")
            description: Tr.tr("settings.appearance.reduceMotionHint")

            Toggle
            {
                objectName: "motionReduce"
                checked: Config.motionReduce
                onToggled: value => Config.set("motionReduce", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.motionStyle")
            stacked: true
            enabled: !Config.motionReduce

            SettingsStyleChoices
            {
                kind: "animation"
                options: Registry.motionStyleOptions
                namePrefix: "motionStyle-"
                current: Config.motionStyle
                onSelected: value => Config.set("motionStyle", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.motionSpeed")
            description: Tr.tr("settings.appearance.motionSpeedHint")
            enabled: !Config.motionReduce && Config.motionStyle !== Enums.MotionDirect

            SettingsSlider
            {
                objectName: "motionSpeed"
                from: 0.25
                to: 2
                step: 0.05
                value: Config.motionSpeed
                valueText: shown.toFixed(2) + "×"
                onMoved: value => Config.set("motionSpeed", value)
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.pointer")

        SettingsRow
        {
            label: Tr.tr("settings.appearance.cursorTheme")
            SettingsDropdown
            {
                enabled: ServiceAppearance.loaded
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
                enabled: ServiceAppearance.loaded
                value: ServiceAppearance.cursorSize
                from: 16; to: 64; step: 2; suffix: " px"
                onEdited: value => ServiceAppearance.setCursorSize(value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.focusFollowsPointer")
            description: Tr.tr("settings.appearance.focusFollowsPointerHint")

            Toggle
            {
                objectName: "focusFollowsPointer"
                checked: Config.focusFollowsPointer
                onToggled: value => ServiceLayout.updatePointer("focusFollowsPointer", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.pointerJumpsFocus")
            description: Tr.tr("settings.appearance.pointerJumpsFocusHint")

            Toggle
            {
                objectName: "pointerJumpsToFocus"
                checked: Config.pointerJumpsToFocus
                onToggled: value => ServiceLayout.updatePointer("pointerJumpsToFocus", value)
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("common.applications")

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
            SettingsDropdown
            {
                enabled: ServiceAppearance.loaded
                options: pageAppearance.withCurrent(ServiceAppearance.iconThemes, ServiceAppearance.iconTheme)
                current: ServiceAppearance.iconTheme
                onSelected: value => ServiceAppearance.setIconTheme(value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.fontFamily")
            SettingsDropdown
            {
                enabled: ServiceAppearance.loaded
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
                enabled: ServiceAppearance.loaded
                value: ServiceAppearance.fontSize
                from: 6; to: 24; step: 1; suffix: " pt"
                onEdited: value => ServiceAppearance.setFontSize(value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.appTheme")
            Button
            {
                text: Tr.tr("settings.appearance.reapply")
                icon: Icon.reload
                enabled: !ServiceAppearance.busy
                onClicked: ServiceAppearance.reapply()
            }
        }
    }

    SettingsRowGroup
    {
        objectName: "appColorsOptions"
        title: Tr.tr("settings.components.appColors")

        SettingsRow
        {
            label: "Kitty"
            description: ServiceColors.kittyError ? Tr.tr("service.colors." + ServiceColors.kittyError) : ""

            Toggle
            {
                objectName: "kittyColorsEnabled"
                checked: Config.kittyColorsEnabled
                onToggled: value => Config.set("kittyColorsEnabled", value)
            }
        }
    }
}
