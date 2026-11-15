pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: serviceGreeter

    readonly property string appearance: JSON.stringify({
        initialized: Config.initialized,
        animations: Config.themeAnimations,
        language: Config.shellLanguage,
        clock24: Config.barWidgetClock24,
        avatar: ServiceUser.avatar,
        keyboardLayouts: ServiceKeyboard.layouts
    })

    onAppearanceChanged: if (Config.initialized) update.restart()
    Component.onCompleted: if (Config.initialized) update.restart()

    property string wallpaper: ""
    property string selection: ""
    property string pendingWallpaper: ""
    property bool installed: false
    property bool writable: false
    property var terminal: []
    property string wallpaperError: ""
    readonly property bool wallpaperBusy: setter.busy || probe.busy || pendingWallpaper !== ""
    signal wallpaperApplied()

    function refresh()
    {
        if (!probe.busy && !setter.busy) probe.run(Paths.commandFor("greeter-wallpaper", ["status", pendingWallpaper]));
    }
    function applyWallpaper(path)
    {
        if (wallpaperBusy || !installed) return;
        wallpaperError = "";
        if (!writable && !terminal.length) { wallpaperError = Tr.tr("settings.dependencies.noTerminal"); return; }
        pendingWallpaper = path;
        const command = Paths.commandFor("greeter-wallpaper", ["apply", path]);
        setter.run(writable ? command : terminal.concat(command, ["--wait"]));
    }

    CommandProcess
    {
        id: probe
        stdout: StdioCollector { id: status }
        onCompleted: code =>
        {
            if (code !== 0)
            {
                serviceGreeter.pendingWallpaper = "";
                serviceGreeter.wallpaperError = errorMessage(Tr.tr("wallpapers.readFailed"));
                return;
            }
            try
            {
                const data = JSON.parse(status.text);
                serviceGreeter.wallpaper = data.wallpaper;
                serviceGreeter.selection = data.selection;
                serviceGreeter.installed = data.installed;
                serviceGreeter.writable = data.writable;
                serviceGreeter.terminal = data.terminal;
                if (serviceGreeter.pendingWallpaper !== "")
                {
                    serviceGreeter.pendingWallpaper = "";
                    if (data.matches) serviceGreeter.wallpaperApplied();
                    else serviceGreeter.wallpaperError = Tr.tr("settings.components.loginFailed");
                }
            }
            catch (error) { serviceGreeter.pendingWallpaper = ""; serviceGreeter.wallpaperError = String(error); }
        }
    }
    CommandProcess
    {
        id: setter
        onCompleted: code =>
        {
            if (code !== 0) { serviceGreeter.pendingWallpaper = ""; serviceGreeter.wallpaperError = errorMessage(Tr.tr("settings.components.loginFailed")); return; }
            Qt.callLater(serviceGreeter.refresh);
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
