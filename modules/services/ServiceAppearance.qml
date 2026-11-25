pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: serviceAppearance

    readonly property var script: Paths.commandFor("appearance")

    property string colorScheme: "default"
    property string iconTheme: ""
    property string cursorTheme: ""
    property int    cursorSize: 24
    property string fontFamily: ""
    property real   fontSize: 10
    property var iconThemes: []
    property var cursorThemes: []
    property var fonts: []

    property bool   loaded: false
    property bool   schemeSyncFailed: false
    property string error: ""

    property var pending: ({})
    readonly property bool busy: writer.busy || flush.running

    function refresh(includeLists = true)
    {
        if (includeLists) schemeSyncFailed = false;
        if (reader.running) reader.refreshPending = true;
        else reader.running = true;
        if (includeLists) lister.running = true;
    }

    function change(key, value)
    {
        const next = Object.assign({}, pending);
        next[key] = value;
        pending = next;
        error = "";
        flush.restart();
    }

    readonly property int effectiveThemeStyle: Config.themeStyle !== Enums.ThemeAuto ? Config.themeStyle
        : Config.wallpaperCurrent && wallpaperThemeSample.light ? Enums.ThemeLight : Enums.ThemeDark
    readonly property string colorSchemeWanted: effectiveThemeStyle === Enums.ThemeLight ? "prefer-light" : "prefer-dark"
    function syncColorScheme() { if (!schemeSyncFailed && Config.initialized && loaded && colorScheme !== colorSchemeWanted) setColorScheme(colorSchemeWanted) }
    onColorSchemeWantedChanged: { schemeSyncFailed = false; syncColorScheme(); }

    function setColorScheme(v) { colorScheme = v; change("color-scheme", v)            }
    function setIconTheme(v)   { iconTheme = v;   change("icon-theme", v)              }
    function setCursorTheme(v) { cursorTheme = v; change("cursor-theme", v)            }
    function setCursorSize(v)  { cursorSize = v;  change("cursor-size", String(v))     }
    function setFontFamily(v)  { fontFamily = v;  change("font", v + " " + fontSize)   }
    function setFontSize(v)    { fontSize = v;    change("font", fontFamily + " " + v) }

    function reapply()
    {
        if (busy) return;
        error = "";
        writer.run(script.concat(["apply"]));
    }

    Timer
    {
        id: flush
        interval: 350
        onTriggered:
        {
            if (writer.busy) { restart(); return; }
            const keys = Object.keys(serviceAppearance.pending);
            if (keys.length === 0) return;

            const command = serviceAppearance.script.concat(["set"]).concat(keys.map(k => k + "=" + serviceAppearance.pending[k]));
            writer.schemeChange = keys.includes("color-scheme");
            serviceAppearance.pending = {};
            writer.run(command);
        }
    }

    CommandProcess
    {
        id: writer
        property bool schemeChange: false

        onCompleted: code =>
        {
            if (code === 0) { schemeChange = false; return; }
            if (schemeChange) serviceAppearance.schemeSyncFailed = true;
            schemeChange = false;
            serviceAppearance.error = writer.errorMessage(Tr.tr("service.appearance.applyFailed"));
            serviceAppearance.refresh(false);
        }
    }

    Process
    {
        id: reader
        property bool refreshPending: false

        command: serviceAppearance.script.concat(["read"])
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const values = {};
                for (const line of text.split("\n"))
                {
                    const eq = line.indexOf("=");
                    if (eq > 0) values[line.substring(0, eq)] = line.substring(eq + 1);
                }
                serviceAppearance.colorScheme = values["color-scheme"] || "default";
                serviceAppearance.iconTheme = values["icon-theme"] || "";
                serviceAppearance.cursorTheme = values["cursor-theme"] || "";
                serviceAppearance.cursorSize = parseInt(values["cursor-size"], 10) || 24;

                const font = String(values["font"] || "").trim();
                const match = /^(.*\S)\s+(\d+(?:\.\d+)?)$/.exec(font);
                serviceAppearance.fontFamily = match ? match[1] : font;
                serviceAppearance.fontSize = match ? parseFloat(match[2]) : 10;

                serviceAppearance.loaded = true;
                serviceAppearance.syncColorScheme();
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") serviceAppearance.error = text.trim() }
        onExited:
        {
            if (!refreshPending) return;
            refreshPending = false;
            Qt.callLater(() => reader.running = true);
        }
    }

    Process
    {
        id: lister

        command: serviceAppearance.script.concat(["list"])
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const lists = { icon: [], cursor: [], font: [] };
                for (const line of text.split("\n"))
                {
                    const tab = line.indexOf("\t");
                    if (tab > 0 && lists[line.substring(0, tab)]) lists[line.substring(0, tab)].push(line.substring(tab + 1));
                }
                const byName = (a, b) => a.localeCompare(b, undefined, { sensitivity: "base" });
                serviceAppearance.iconThemes = Array.from(new Set(lists.icon)).sort(byName);
                serviceAppearance.cursorThemes = Array.from(new Set(lists.cursor)).sort(byName);
                serviceAppearance.fonts = Array.from(new Set(lists.font)).sort(byName);
            }
        }
    }

    property var icons: ({})
    function iconPath(name)
    {
        if (!name) return "";
        const path = icons[name];
        return path ? "file://" + path : Quickshell.iconPath(name, true);
    }

    onIconThemeChanged:
    {
        if (iconTheme === "") return;
        iconsReader.running = false;
        iconsReader.command = script.concat(["icons", iconTheme]);
        iconsReader.running = true;
    }

    Process
    {
        id: iconsReader
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const all = {};
                for (const line of text.split("\n"))
                {
                    const tab = line.indexOf("\t");
                    if (tab > 0) all[line.substring(0, tab)] = line.substring(tab + 1);
                }
                serviceAppearance.icons = all;
                if (Config.debug) console.log("[icons] " + serviceAppearance.iconTheme + ": " + Object.keys(all).length + " icons");
            }
        }
    }

    property string wallpaperError: ""
    property int wallpaperRevision: 0
    property var wallpaperSnapshot: ({path: "", preview: ""})
    property var pendingWallpaperSnapshot: null
    readonly property string wallpaperImage: isVideo(Config.wallpaperCurrent)
        ? (wallpaperSnapshot.path === Config.wallpaperCurrent ? wallpaperSnapshot.preview : "") : Config.wallpaperCurrent
    readonly property string wallpaperThemeRequest: Config.initialized && Config.themeStyle === Enums.ThemeAuto && wallpaperImage
        ? JSON.stringify([wallpaperImage, wallpaperRevision]) : ""
    property var wallpaperThemeSample: ({key: "", light: false})

    onWallpaperThemeRequestChanged: if (wallpaperThemeRequest) brightnessTimer.restart()

    Timer
    {
        id: brightnessTimer
        interval: 80
        onTriggered:
        {
            const key = serviceAppearance.wallpaperThemeRequest;
            if (!key || brightnessProbe.busy || serviceAppearance.wallpaperThemeSample.key === key) return;
            brightnessProbe.key = key;
            brightnessProbe.run(Paths.commandFor("colors", ["brightness", serviceAppearance.wallpaperImage]));
        }
    }
    CommandProcess
    {
        id: brightnessProbe
        property string key: ""
        stdout: StdioCollector { id: brightnessResult }
        onCompleted: code =>
        {
            if (key !== serviceAppearance.wallpaperThemeRequest)
            {
                if (serviceAppearance.wallpaperThemeRequest) brightnessTimer.restart();
                return;
            }
            let light = false;
            if (code === 0)
            {
                try { light = JSON.parse(brightnessResult.text)?.light === true; }
                catch (_) {}
            }
            serviceAppearance.wallpaperThemeSample = {key, light};
        }
    }

    function rememberWallpaper(path, preview)
    {
        wallpaperSnapshot = {path: path, preview: preview || ""};
    }
    function commitWallpaper(data)
    {
        rememberWallpaper(data.path, data.preview);
        Config.set("wallpaperCurrent", data.path);
    }

    LockWallpaperPreview
    {
        id: lockPreview
        visible: false
        source: serviceAppearance.fileUrl(serviceAppearance.wallpaperImage)
    }

    property string pendingWallpaper: ""
    property string videoPath: ""
    property string readyVideoPath: ""
    onVideoPathChanged: readyVideoPath = ""
    property string previousWallpaper: ""
    property bool restoringWallpaper: false
    property var videoComponent: null
    readonly property bool wallpaperBusy: wallpaperWriter.busy || pendingWallpaper !== "" || restoringWallpaper
    signal wallpaperApplied()

    function isVideo(path) { return /\.(mp4|webm|mkv|mov|m4v|avi)$/i.test(path); }
    function fileUrl(path) { return path ? "file://" + String(path).replace(/^file:\/\//, "").split("/").map(encodeURIComponent).join("/") : ""; }
    function prepareVideo()
    {
        if (videoComponent && videoComponent.status === Component.Error) { videoComponent.destroy(); videoComponent = null; }
        if (!videoComponent) videoComponent = Qt.createComponent(Qt.resolvedUrl("../ui/desktop/VideoWallpaper.qml"));
        return videoComponent.status === Component.Ready;
    }
    function applyWallpaper(path)
    {
        if (!path || wallpaperBusy) return false;
        wallpaperError = "";
        if (isVideo(path) && !prepareVideo())
        {
            wallpaperError = Tr.tr("wallpapers.videoDependency");
            return false;
        }
        previousWallpaper = Config.wallpaperCurrent;
        return wallpaperWriter.run(Paths.commandFor("wallpaper", ["apply", path, "--transition", Config.animationsEnabled ? Config.wallpaperTransition : "none"]));
    }
    function clearPendingWallpaper()
    {
        pendingWallpaper = "";
        pendingWallpaperSnapshot = null;
        videoTimeout.stop();
    }
    function finishWallpaper(data)
    {
        if (Config.wallpaperCurrent === data.path) wallpaperRevision++;
        commitWallpaper(data);
        clearPendingWallpaper();
        wallpaperApplied();
    }
    function videoReady(path)
    {
        readyVideoPath = path;
        if (pendingWallpaper !== path) return;
        finishWallpaper(pendingWallpaperSnapshot);
    }
    function videoFailed(path, message)
    {
        wallpaperError = message || Tr.tr("wallpapers.videoFailed");
        if (pendingWallpaper !== path) return;
        clearPendingWallpaper();
        videoPath = isVideo(previousWallpaper) ? previousWallpaper : "";
        if (previousWallpaper)
        {
            restoringWallpaper = true;
            wallpaperWriter.run(Paths.commandFor("wallpaper", ["apply", previousWallpaper, "--transition", "none"]));
        }
    }
    Timer
    {
        id: videoTimeout
        interval: 15000
        onTriggered: if (serviceAppearance.pendingWallpaper) serviceAppearance.videoFailed(serviceAppearance.pendingWallpaper, Tr.tr("wallpapers.videoFailed"))
    }
    Connections
    {
        target: ServiceLock
        function onLockedChanged()
        {
            if (ServiceLock.locked) videoTimeout.stop();
            else if (serviceAppearance.pendingWallpaper) videoTimeout.restart();
        }
    }
    CommandProcess
    {
        id: wallpaperWriter
        stdout: StdioCollector { id: wallpaperResult }
        onCompleted: code =>
        {
            if (serviceAppearance.restoringWallpaper)
            {
                serviceAppearance.restoringWallpaper = false;
                if (code === 0)
                {
                    try
                    {
                        const data = JSON.parse(wallpaperResult.text);
                        serviceAppearance.commitWallpaper(data);
                    }
                    catch (error) { }
                }
                return;
            }
            if (code !== 0) { serviceAppearance.wallpaperError = errorMessage(Tr.tr("wallpapers.applyFailed")); return; }
            try
            {
                const data = JSON.parse(wallpaperResult.text);
                if (data.video)
                {
                    if (serviceAppearance.readyVideoPath === data.path)
                    {
                        serviceAppearance.finishWallpaper(data);
                        return;
                    }
                    serviceAppearance.pendingWallpaperSnapshot = data;
                    serviceAppearance.pendingWallpaper = data.path;
                    serviceAppearance.videoPath = data.path;
                    if (serviceAppearance.pendingWallpaper) videoTimeout.restart();
                }
                else
                {
                    serviceAppearance.videoPath = "";
                    serviceAppearance.finishWallpaper(data);
                }
            }
            catch (error) { serviceAppearance.wallpaperError = String(error); }
        }
    }
    CommandProcess
    {
        id: wallpaperCheck
        property string selection: ""
        stdout: StdioCollector { id: wallpaperCurrent }
        onCompleted: code =>
        {
            if (code !== 0 || Config.wallpaperCurrent !== selection) return;
            try
            {
                const data = JSON.parse(wallpaperCurrent.text);
                if (!data.path) return;
                if (serviceAppearance.wallpaperBusy)
                {
                    serviceAppearance.rememberWallpaper(selection, data.preview);
                    return;
                }
                serviceAppearance.commitWallpaper(data);
                if (data.video && serviceAppearance.prepareVideo()) serviceAppearance.videoPath = data.path;
            }
            catch (error) { serviceAppearance.wallpaperError = String(error); }
        }
    }


    property bool wallpaperInitialized: false
    function initializeWallpaper()
    {
        if (!Config.initialized || wallpaperInitialized) return;
        wallpaperInitialized = true;
        refresh(false);
        if (!Config.wallpaperCurrent)
        {
            applyWallpaper(Paths.shellDir + "/assets/wallpapers/default.png");
            return;
        }
        wallpaperCheck.selection = Config.wallpaperCurrent;
        wallpaperCheck.run(Paths.commandFor("wallpaper", ["inspect", wallpaperCheck.selection]));
    }
    Component.onCompleted: initializeWallpaper()

    Connections
    {
        target: Config
        function onInitializedChanged() { serviceAppearance.initializeWallpaper() }
    }
}
