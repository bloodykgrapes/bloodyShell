pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    title: Tr.tr("settings.appearance.wallpaper")
    subtitle: Tr.tr("settings.wallpaper.description")

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.library")

        SettingsRow
        {
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
            label: Tr.tr("settings.appearance.wallpaperFolder")
            SettingsInput
            {
                objectName: "wallpaperDirectory"
                text: Config.wallpaperDirectory
                placeholderText: "~/Pictures/Wallpapers"
                onEditingFinished:
                {
                    const next = text.trim();
                    if (next !== "") Config.set("wallpaperDirectory", next);
                    text = Config.wallpaperDirectory;
                }
            }
        }

        ShellText
        {
            width: parent.width
            visible: ServiceAppearance.wallpaperError !== "" || ServiceWallpapers.error !== ""
            label: ServiceAppearance.wallpaperError || ServiceWallpapers.error
            color: Theme.colorCritical
            wrapMode: Text.Wrap
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.appearance.wallpaperShuffle")

        SettingsRow
        {
            label: Tr.tr("common.enabled")
            Toggle
            {
                objectName: "wallpaperShuffle"
                checked: Config.wallpaperShuffle
                onToggled: value => Config.set("wallpaperShuffle", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.wallpaperEvery")
            enabled: Config.wallpaperShuffle

            SettingsSlider
            {
                objectName: "wallpaperShuffleMinutes"
                from: 5
                to: 360
                step: 5
                value: Config.wallpaperShuffleMinutes
                valueText: Math.round(shown) + " " + Tr.tr("common.minutesShort")
                onMoved: value => Config.set("wallpaperShuffleMinutes", Math.round(value))
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.transition")

        SettingsRow
        {
            label: Tr.tr("common.enabled")
            Toggle
            {
                objectName: "wallpaperTransitionEnabled"
                checked: Config.wallpaperTransitionEnabled
                onToggled: value => Config.set("wallpaperTransitionEnabled", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("common.style")
            enabled: Config.wallpaperTransitionEnabled

            SettingsDropdown
            {
                objectName: "wallpaperTransitionSelector"
                options: [
                    { label: Tr.tr("common.off"), value: "none" },
                    { label: Tr.tr("settings.appearance.wallpaperSimple"), value: "simple" },
                    { label: Tr.tr("settings.appearance.wallpaperFade"), value: "fade" },
                    { label: Tr.tr("settings.appearance.wallpaperLeft"), value: "left" },
                    { label: Tr.tr("settings.appearance.wallpaperRight"), value: "right" },
                    { label: Tr.tr("settings.appearance.wallpaperTop"), value: "top" },
                    { label: Tr.tr("settings.appearance.wallpaperBottom"), value: "bottom" },
                    { label: Tr.tr("settings.appearance.wallpaperWipe"), value: "wipe" },
                    { label: Tr.tr("settings.appearance.wallpaperWave"), value: "wave" },
                    { label: Tr.tr("settings.appearance.wallpaperGrow"), value: "grow" },
                    { label: Tr.tr("settings.appearance.wallpaperCenter"), value: "center" },
                    { label: Tr.tr("settings.appearance.wallpaperAny"), value: "any" },
                    { label: Tr.tr("settings.appearance.wallpaperShrink"), value: "outer" },
                    { label: Tr.tr("settings.appearance.wallpaperRandom"), value: "random" }
                ]
                current: Config.wallpaperTransition
                onSelected: value => Config.set("wallpaperTransition", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.wallpaperDuration")
            enabled: Config.wallpaperTransitionEnabled

            SettingsSlider
            {
                objectName: "wallpaperTransitionDuration"
                from: 200
                to: 3000
                step: 100
                value: Config.wallpaperTransitionDuration
                valueText: (shown / 1000).toFixed(1) + " " + Tr.tr("common.secondsShort")
                onMoved: value => Config.set("wallpaperTransitionDuration", Math.round(value))
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.appearance.wallpaperLive")

        SettingsRow
        {
            label: Tr.tr("settings.appearance.wallpaperPause")
            stacked: true

            SettingsChoices
            {
                objectName: "wallpaperLivePause"
                options: Registry.wallpaperPauseOptions
                current: Config.wallpaperLivePause
                onSelected: value => Config.set("wallpaperLivePause", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.wallpaperPauseOnBattery")
            Toggle
            {
                objectName: "wallpaperPauseOnBattery"
                checked: Config.wallpaperPauseOnBattery
                onToggled: value => Config.set("wallpaperPauseOnBattery", value)
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.effects")

        SettingsRow
        {
            label: Tr.tr("settings.appearance.wallpaperBlur")
            Toggle
            {
                objectName: "wallpaperBlur"
                checked: Config.wallpaperBlur
                onToggled: value => Config.set("wallpaperBlur", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.wallpaperBlurStrength")
            enabled: Config.wallpaperBlur

            SettingsSlider
            {
                objectName: "wallpaperBlurStrength"
                value: Config.wallpaperBlurStrength
                from: 0
                to: 100
                step: 1
                onMoved: value => Config.set("wallpaperBlurStrength", Math.round(value))
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.overviewBackdrop")
            description: Tr.tr("settings.appearance.overviewBackdropHint")
            Toggle
            {
                objectName: "overviewBackdrop"
                checked: Config.overviewBackdrop
                onToggled: value => Config.set("overviewBackdrop", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.overviewBlur")
            enabled: Config.overviewBackdrop

            SettingsSlider
            {
                objectName: "overviewBlur"
                value: Config.overviewBlur
                from: 0
                to: 100
                step: 1
                onMoved: value => Config.set("overviewBlur", Math.round(value))
            }
        }
    }
}
