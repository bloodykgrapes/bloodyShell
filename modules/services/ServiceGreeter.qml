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
        avatar: ServiceUser.avatar,
        keyboardLayouts: ServiceKeyboard.layouts
    })

    onAppearanceChanged: if (Config.initialized) update.restart()
    Component.onCompleted: if (Config.initialized) update.restart()

    Connections
    {
        target: Config
        function onGreeterSyncChanged()
        {
            if (Config.initialized) update.restart();
            else update.stop();
        }
    }

    Timer
    {
        id: update
        interval: 700
        onTriggered:
        {
            if (!Config.initialized) return;
            if (exporter.busy) { restart(); return; }
            const layouts = ServiceKeyboard.layouts.length ? ServiceKeyboard.layouts : [{layout: "us", variant: ""}];
            exporter.run(Paths.commandFor("greeter-settings", [Config.file, "/var/lib/bloodyShell", "--if-configured", "--keyboard-layouts", JSON.stringify(layouts)]));
        }
    }

    CommandProcess
    {
        id: exporter
        onCompleted: code => { if (code !== 0) console.warn(exporter.errorMessage("Could not update greeter appearance")); }
    }
}
