pragma Singleton

import QtQuick
import Quickshell

import "../common"
import "../core"

Singleton
{
    id: serviceGreeter

    readonly property string appearance: JSON.stringify({
        initialized: Config.initialized,
        wallpaper: Config.wallpaperCurrent,
        animations: Config.themeAnimations,
        language: Config.shellLanguage,
        clock24: Config.barWidgetClock24,
        avatar: ServiceUser.avatar
    })

    onAppearanceChanged: if (Config.initialized) update.restart()
    Component.onCompleted: if (Config.initialized) update.restart()

    Timer
    {
        id: update
        interval: 700
        onTriggered:
        {
            if (exporter.busy) { restart(); return; }
            exporter.run(["python3", Paths.shellDir + "/greeter/export-settings", Config.file, "/var/lib/bloodyShell", "--if-configured"]);
        }
    }

    CommandProcess
    {
        id: exporter
        onCompleted: code => { if (code !== 0) console.warn(exporter.errorMessage("Could not update greeter appearance")); }
    }
}
