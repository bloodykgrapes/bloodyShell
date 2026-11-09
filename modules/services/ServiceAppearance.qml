pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: serviceAppearance

    readonly property string script: Paths.runtimeScriptsDir + "/appearance"

    property string colorScheme: "default"
    property string gtkTheme: ""
    property string iconTheme: ""
    property string cursorTheme: ""
    property int    cursorSize: 24
    property string fontFamily: ""
    property real   fontSize: 10
    property bool   qt6ct: false

    property var gtkThemes: []
    property var iconThemes: []
    property var cursorThemes: []
    property var fonts: []

    property bool   loaded: false
    property string error: ""

    property var pending: ({})

    function refresh(includeLists = true)
    {
        reader.running = true;
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
    function syncColorScheme() { if (Config.initialized && loaded && colorScheme !== colorSchemeWanted) setColorScheme(colorSchemeWanted) }
    onColorSchemeWantedChanged: syncColorScheme()

    function setColorScheme(v) { colorScheme = v; change("color-scheme", v)            }
    function setGtkTheme(v)    { gtkTheme = v;    change("gtk-theme", v)               }
    function setIconTheme(v)   { iconTheme = v;   change("icon-theme", v)              }
    function setCursorTheme(v) { cursorTheme = v; change("cursor-theme", v)            }
    function setCursorSize(v)  { cursorSize = v;  change("cursor-size", String(v))     }
    function setFontFamily(v)  { fontFamily = v;  change("font", v + " " + fontSize)   }
    function setFontSize(v)    { fontSize = v;    change("font", fontFamily + " " + v) }

    function reapply()
    {
        if (writer.busy) return;
        error = "";
        writer.run([script, "apply"]);
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

            const command = [serviceAppearance.script, "set"].concat(keys.map(k => k + "=" + serviceAppearance.pending[k]));
            serviceAppearance.pending = {};
            writer.run(command);
        }
    }

    CommandProcess
    {
        id: writer

        onCompleted: code =>
        {
            if (code === 0) return;
            serviceAppearance.error = writer.errorMessage(Tr.tr("service.appearance.applyFailed"));
            serviceAppearance.refresh(false);
        }
    }

    Process
    {
        id: reader

        command: [serviceAppearance.script, "read"]
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
                serviceAppearance.gtkTheme = values["gtk-theme"] || "";
                serviceAppearance.iconTheme = values["icon-theme"] || "";
                serviceAppearance.cursorTheme = values["cursor-theme"] || "";
                serviceAppearance.cursorSize = parseInt(values["cursor-size"], 10) || 24;
                serviceAppearance.qt6ct = values["qt6ct"] === "yes";

                const font = String(values["font"] || "").trim();
                const match = /^(.*\S)\s+(\d+(?:\.\d+)?)$/.exec(font);
                serviceAppearance.fontFamily = match ? match[1] : font;
                serviceAppearance.fontSize = match ? parseFloat(match[2]) : 10;

                serviceAppearance.loaded = true;
                serviceAppearance.syncColorScheme();
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") serviceAppearance.error = text.trim() }
    }

    Process
    {
        id: lister

        command: [serviceAppearance.script, "list"]
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const lists = { gtk: [], icon: [], cursor: [], font: [] };
                for (const line of text.split("\n"))
                {
                    const tab = line.indexOf("\t");
                    if (tab > 0 && lists[line.substring(0, tab)]) lists[line.substring(0, tab)].push(line.substring(tab + 1));
                }
                const byName = (a, b) => a.localeCompare(b, undefined, { sensitivity: "base" });
                serviceAppearance.gtkThemes = Array.from(new Set(lists.gtk)).sort(byName);
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
        iconsReader.command = [script, "icons", iconTheme];
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

    readonly property string wallpaperCheckScript:
        "[ -n \"$1\" ] && [ -f \"$1\" ] && { echo keep; exit; }; "
        + "q=$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1); [ -n \"$q\" ] && [ -f \"$q\" ] && { echo \"set $q\"; exit; }; "
        + "f=$(find \"$2\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort | head -n1); "
        + "[ -n \"$f\" ] && echo \"apply $f\""

    Process
    {
        id: wallpaperCheck
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const line = text.trim(), space = line.indexOf(" ");
                const action = space > 0 ? line.substring(0, space) : line, path = line.substring(space + 1);
                if (action === "keep") serviceAppearance.analyzeWallpaper(Config.wallpaperCurrent);
                else if (action === "set") { Config.set("wallpaperCurrent", path); serviceAppearance.analyzeWallpaper(path); }
                else if (action === "apply") serviceAppearance.applyWallpaper(path);
            }
        }
    }

    function applyWallpaper(path)
    {
        if (!path) return;
        Config.set("wallpaperCurrent", path);
        Quickshell.execDetached(["awww", "img", path,
            "--transition-type", "grow", "--transition-pos", "center",
            "--transition-duration", "1.2", "--transition-fps", "120",
            "--transition-bezier", Theme.easingEmphasized.slice(0, 4).join(",")]);
        analyzeWallpaper(path);
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
            wallpaperCheck.command = ["sh", "-c", serviceAppearance.wallpaperCheckScript, "check", Config.wallpaperCurrent, Config.wallpaperDirectory];
            wallpaperCheck.running = true;
        }
    }

    function analyzeWallpaper(path)
    {
        if (!path) return;
        sampler.command = ["sh", "-c", "ffmpeg -loglevel error -i \"$1\" -frames:v 1 -vf scale=24:24:flags=area -f rawvideo -pix_fmt rgb24 - | od -An -tu1 -v",
                           "sampler", String(path).replace(/^file:\/\//, "")];
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
                const values = text.trim().split(/\s+/).map(n => parseInt(n, 10)).filter(n => !isNaN(n));
                if (values.length < 30) return;
                serviceAppearance.wallpaperAccent = serviceAppearance.pickAccent(values);
            }
        }
    }
}
