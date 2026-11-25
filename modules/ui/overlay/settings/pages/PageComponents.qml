import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageComponents

    title: Tr.tr("settings.components.title")
    Component.onCompleted: ServiceGreeter.refresh()

    SettingsDisclosure
    {
        objectName: "virtualKeyboardOptions"
        title: Tr.tr("keyboard.title")
        icon: Icon.keyboard
        SettingsRow
        {
            label: Tr.tr("keyboard.mode")
            SettingsChoices
            {
                objectName: "virtualKeyboardMode"
                options: [{label: Tr.tr("keyboard.disabled"), value: false}, {label: Tr.tr("keyboard.showAtBar"), value: true}]
                current: Config.virtualKeyboardEnabled
                onSelected: value => Config.set("virtualKeyboardEnabled", value)
            }
        }
    }

    SettingsDisclosure
    {
        objectName: "visualizerOptions"
        title: Tr.tr("settings.components.visualizer")
        icon: Icon.visualizer

        SettingsRow
        {
            label: Tr.tr("common.style")
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
        SettingsRow
        {
            label: Tr.tr("settings.components.visualizerOpacity")
            SettingsSlider
            {
                objectName: "visualizerOpacity"
                from: 0.25
                step: 0.05
                value: Config.desktopEqualizerOpacity
                valueText: Math.round(shown * 100) + "%"
                onMoved: value => Config.set("desktopEqualizerOpacity", value)
            }
        }
    }

    SettingsEasyEffects { objectName: "easyEffectsSection"; active: pageComponents.active }

    SettingsPlymouth
    {
        objectName: "plymouthSection"
        active: pageComponents.active
        onRevealRequested: item => pageComponents.revealItem(item)
    }

    SettingsDisclosure
    {
        objectName: "appColorsOptions"
        title: Tr.tr("settings.components.appColors")
        icon: Icon.settingsAppearance
        onExpandedChanged: if (expanded) ServiceColors.refresh()

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

    SettingsDisclosure
    {
        objectName: "screenshotOptions"
        title: Tr.tr("settings.components.screenshots")
        icon: Icon.screenshot

        SettingsRow
        {
            label: Tr.tr("settings.components.savePath")
            SettingsInput
            {
                objectName: "screenshotsPath"
                text: Config.screenshotsPath || Config.screenshotsDefault()
                onEditingFinished:
                {
                    Config.set("screenshotsPath", text.trim() || Config.screenshotsDefault());
                    text = Config.screenshotsPath;
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.components.action")
            SettingsChoices
            {
                objectName: "screenshotsAction"
                options: [{label: Tr.tr("screenshot.copy"), value: "copy"}, {label: Tr.tr("screenshot.save"), value: "save"}]
                current: Config.screenshotsAction
                onSelected: value => Config.set("screenshotsAction", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.components.instantly")
            description: Tr.tr("settings.components.instantlyHint")
            Toggle
            {
                objectName: "screenshotsInstantly"
                checked: Config.screenshotsInstantly
                onToggled: value => Config.set("screenshotsInstantly", value)
            }
        }
    }

    SettingsDisclosure
    {
        objectName: "loginOptions"
        title: Tr.tr("settings.imports.greeter")
        icon: Icon.loginScreen

        SettingsRow
        {
            label: Tr.tr("settings.appearance.wallpaper")
            description: Tr.tr(ServiceGreeter.installed ? "settings.components.loginHint" : "settings.components.loginMissing")
            stacked: true
            WallpaperPreview
            {
                objectName: "loginWallpaperPreview"
                width: parent.width
                height: implicitHeight
                wallpaper: ServiceGreeter.wallpaper
                enabled: ServiceGreeter.installed && !ServiceGreeter.wallpaperBusy
                onClicked: OverlayState.show("wallpapers", "login")
            }
        }
        ShellText
        {
            visible: ServiceGreeter.wallpaperError !== ""
            width: parent.width
            label: ServiceGreeter.wallpaperError
            wrapMode: Text.Wrap
            color: Theme.colorCritical
        }
    }
}
