pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: service

    readonly property string folder: String(Config.wallpaperDirectory || "").replace(/^~(?=\/|$)/, Paths.home)
    property var catalog: null
    property bool scanAgain: false
    readonly property bool loading: scan.busy || scanAgain
    property string error: ""

    Component.onCompleted: refresh()
    onFolderChanged: refresh(true)

    function shuffle()
    {
        const paths = catalog?.paths || [];
        if (!Config.wallpaperShuffle || paths.length < 2 || ServiceAppearance.wallpaperBusy) return;
        const candidates = paths.filter(path => path !== Config.wallpaperCurrent);
        const next = candidates[Math.floor(Math.random() * candidates.length)];
        if (next) ServiceAppearance.applyWallpaper(next);
    }

    Timer
    {
        interval: Math.max(1, Config.wallpaperShuffleMinutes) * 60000
        running: Config.wallpaperShuffle && (service.catalog?.paths.length || 0) > 1
        repeat: true
        onRunningChanged: if (running) restart()
        onTriggered: service.shuffle()
    }

    function refresh(force = false)
    {
        if (scan.busy)
        {
            if (force || scan.folder !== folder) scanAgain = true;
            return;
        }
        scanAgain = false;
        error = "";
        if (!folder)
        {
            publish(folder, []);
            return;
        }
        scan.folder = folder;
        scan.run(Paths.commandFor("wallpaper", ["list", folder]));
    }

    function publish(directory, paths)
    {
        if (catalog?.folder === directory && catalog.paths.length === paths.length
            && paths.every((path, i) => path === catalog.paths[i])) return;
        catalog = { folder: directory, paths: paths };
    }

    CommandProcess
    {
        id: scan
        property string folder: ""
        stdout: StdioCollector { id: result }
        onCompleted: code =>
        {
            if (folder === service.folder)
            {
                let paths = null;
                if (code === 0)
                {
                    try
                    {
                        const list = JSON.parse(result.text).paths;
                        if (Array.isArray(list) && list.every(path => typeof path === "string"))
                            paths = list.sort((a, b) => a.localeCompare(b, undefined, {numeric: true}));
                    }
                    catch (_) {}
                }
                if (paths) service.publish(folder, paths);
                else
                {
                    service.error = errorMessage(Tr.tr("wallpapers.readFailed"));
                    if (service.catalog?.folder !== folder) service.publish(folder, []);
                }
            }
            if (service.scanAgain) Qt.callLater(service.refresh);
        }
    }
}
