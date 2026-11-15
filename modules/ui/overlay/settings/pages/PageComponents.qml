import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    title: Tr.tr("settings.components.title")
    Component.onCompleted: ServiceGreeter.refresh()

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
