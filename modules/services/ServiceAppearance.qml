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

    readonly property string colorSchemeWanted: Config.themeStyle === Enums.ThemeLight ? "prefer-light" : "prefer-dark"
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
    function videoReady(path)
    {
        readyVideoPath = path;
        if (pendingWallpaper !== path) return;
        Config.set("wallpaperCurrent", path);
        pendingWallpaper = "";
        videoTimeout.stop();
        wallpaperApplied();
    }
    function videoFailed(path, message)
    {
        wallpaperError = message || Tr.tr("wallpapers.videoFailed");
        if (pendingWallpaper !== path) return;
        pendingWallpaper = "";
        videoTimeout.stop();
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
                    try { serviceAppearance.analyzeWallpaper(JSON.parse(wallpaperResult.text).preview); }
                    catch (error) { }
                }
                return;
            }
            if (code !== 0) { serviceAppearance.wallpaperError = errorMessage(Tr.tr("wallpapers.applyFailed")); return; }
            try
            {
                const data = JSON.parse(wallpaperResult.text);
                serviceAppearance.analyzeWallpaper(data.preview);
                if (data.video)
                {
                    if (serviceAppearance.readyVideoPath === data.path)
                    {
                        Config.set("wallpaperCurrent", data.path);
                        serviceAppearance.wallpaperApplied();
                        return;
                    }
                    serviceAppearance.pendingWallpaper = data.path;
                    serviceAppearance.videoPath = data.path;
                    if (serviceAppearance.pendingWallpaper) videoTimeout.restart();
                }
                else
                {
                    serviceAppearance.videoPath = "";
                    Config.set("wallpaperCurrent", data.path);
                    serviceAppearance.wallpaperApplied();
                }
            }
            catch (error) { serviceAppearance.wallpaperError = String(error); }
        }
    }
    CommandProcess
    {
        id: wallpaperCheck
        stdout: StdioCollector { id: wallpaperCurrent }
        onCompleted: code =>
        {
            if (code !== 0) return;
            try
            {
                const data = JSON.parse(wallpaperCurrent.text);
                if (!data.path) return;
                Config.set("wallpaperCurrent", data.path);
                serviceAppearance.analyzeWallpaper(data.preview);
                if (data.video && serviceAppearance.prepareVideo()) serviceAppearance.videoPath = data.path;
            }
            catch (error) { serviceAppearance.wallpaperError = String(error); }
        }
    }

    property string wallpaperAccent: ""
    readonly property string accent: wallpaperAccent !== "" ? wallpaperAccent : "#8ecbff"

    Connections
    {
        target: Config
        function onInitializedChanged()
        {
            if (!Config.initialized) return;
            serviceAppearance.refresh(false);
            wallpaperCheck.run(Paths.commandFor("wallpaper", ["inspect", Config.wallpaperCurrent]));
        }
    }

    function analyzeWallpaper(path)
    {
        if (!path) return;
        sampler.running = false;
        sampler.command = Paths.commandFor("wallpaper", ["colors", String(path).replace(/^file:\/\//, "")]);
        sampler.running = true;
    }

    function hsl(r, g, b)
    {
        r /= 255; g /= 255; b /= 255;
        const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2;
        if (max === min) return [0, 0, l];
        const d = max - min;
        const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        const h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
        return [h * 60, s, l];
    }

    function pickAccent(values)
    {
        const bins = new Array(36).fill(0), sumX = new Array(36).fill(0), sumY = new Array(36).fill(0), sumS = new Array(36).fill(0);
        for (let i = 0; i + 2 < values.length; i += 3)
        {
            const [h, s, l] = hsl(values[i], values[i + 1], values[i + 2]);
            if (l < 0.12 || l > 0.92 || s < 0.18) continue;
            const w = s * (1 - Math.abs(l - 0.5));
            const bin = Math.floor(h / 10) % 36;
            bins[bin] += w;
            sumX[bin] += Math.cos(h * Math.PI / 180) * w;
            sumY[bin] += Math.sin(h * Math.PI / 180) * w;
            sumS[bin] += s * w;
        }

        let best = -1, bestWeight = 0;
        for (let b = 0; b < 36; b++)
        {
            const weight = bins[b] + 0.5 * (bins[(b + 35) % 36] + bins[(b + 1) % 36]);
            if (weight > bestWeight) { bestWeight = weight; best = b; }
        }
        if (best < 0 || bestWeight < 0.5) return Qt.hsla(0, 0, 0.82, 1).toString();

        let x = 0, y = 0, sat = 0, wsum = 0;
        for (const b of [(best + 35) % 36, best, (best + 1) % 36]) { x += sumX[b]; y += sumY[b]; sat += sumS[b]; wsum += bins[b]; }
        const hue = ((Math.atan2(y, x) * 180 / Math.PI) + 360) % 360;
        const saturation = Math.max(0.55, Math.min(0.9, (sat / wsum) * 1.1));
        return Qt.hsla(hue / 360, saturation, 0.78, 1).toString();
    }

    Process
    {
        id: sampler
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                try
                {
                    const values = JSON.parse(text);
                    if (values.length >= 30) serviceAppearance.wallpaperAccent = serviceAppearance.pickAccent(values);
                }
                catch (error) { if (Config.debug) console.warn("Could not sample wallpaper colors"); }
            }
        }
    }
}
