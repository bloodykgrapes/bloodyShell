pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageLogin
    title: Tr.tr("settings.imports.greeter")
    Component.onCompleted: ServiceGreeter.refresh()

    SettingsRowGroup
    {
        objectName: "loginOptions"
        title: Tr.tr("settings.imports.greeter")

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
