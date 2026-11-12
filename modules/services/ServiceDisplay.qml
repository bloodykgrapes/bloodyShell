pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"
import "../src/Kdl.js" as Kdl

Singleton
{
    id: serviceDisplay

    readonly property var helper: Paths.commandFor("niri-config")

    property var    outputs: []
    property bool   loaded: false
    property string error: ""

    property var pending: null
    property int countdown: 0
    readonly property bool confirming: pending !== null

    readonly property var riskyKeys: ["mode", "transform", "enabled"]

    function refresh() { reader.running = true }

    function output(name) { return outputs.find(o => o.name === name) || null }

    function modeString(m) { return m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3) }

    function transformName(t)
    {
        const s = String(t || "Normal").toLowerCase().replace(/^_/, "");
        return s.startsWith("flipped") && s.length > 7 ? "flipped-" + s.substring(7) : s;
    }

    function stateOf(name)
    {
        const o = output(name);
        const mode = o && o.current_mode !== null ? o.modes[o.current_mode] : null;
        const logical = o ? o.logical : null;
        return Object.assign({
            mode: mode ? modeString(mode) : "",
            scale: logical ? logical.scale : 1,
            transform: logical ? transformName(logical.transform) : "normal",
            position: null,
            vrr: o && o.vrr_enabled ? "on" : "off",
            enabled: o ? logical !== null : true
        }, (Config.displays || {})[name] || {});
    }

    function change(name, key, value)
    {
        if (confirming) keep();

        const before = stateOf(name);
        if (JSON.stringify(before[key]) === JSON.stringify(value)) return;

        if (key === "position" && value)
        {
            savePositions(name, value);
            return;
        }

        const after = Object.assign({}, before, { [key]: value });
        applyLive(name, key, after);

        if (riskyKeys.indexOf(key) >= 0)
        {
            pending = { name: name, key: key, before: before, after: after };
            countdown = 15;
            ticker.restart();
        }
        else save(name, after);
    }

    function keep()
    {
        if (!pending) return;
        const p = pending;
        pending = null;
        ticker.stop();
        save(p.name, p.after);
    }

    function revert()
    {
        if (!pending) return;
        const p = pending;
        pending = null;
        ticker.stop();
        applyLive(p.name, p.key, p.before);
        refreshSoon.restart();
    }

    Timer
    {
        id: ticker
        interval: 1000
        repeat: true
        onTriggered: if (--serviceDisplay.countdown <= 0) serviceDisplay.revert()
    }

    function applyLive(name, key, state)
    {
        let args;
        switch (key)
        {
            case "mode":      args = ["mode", state.mode || "auto"]; break;
            case "scale":     args = ["scale", String(state.scale)]; break;
            case "transform": args = ["transform", state.transform]; break;
            case "enabled":   args = [state.enabled ? "on" : "off"]; break;
            case "vrr":       args = state.vrr === "on-demand" ? ["vrr", "on", "--on-demand"] : ["vrr", state.vrr]; break;
            case "position":  args = state.position ? ["position", "set", String(state.position.x), String(state.position.y)] : ["position", "auto"]; break;
            default: return;
        }
        Quickshell.execDetached(["niri", "msg", "output", name].concat(args));
        refreshSoon.restart();
    }

    function save(name, state)
    {
        const all = Object.assign({}, Config.displays || {});
        all[name] = state;
        commit(all);
    }

    function savePositions(name, position)
    {
        // Pin neighbouring outputs so niri's automatic placement keeps them in place.
        const all = Object.assign({}, Config.displays || {});
        for (const output of outputs.filter(output => output.logical))
        {
            const state = stateOf(output.name);
            all[output.name] = Object.assign({}, state, {
                position: output.name === name ? position : state.position || { x: output.logical.x, y: output.logical.y }
            });
        }
        commit(all);
    }

    function commit(all)
    {
        Config.set("displays", all);
        write(all);
    }

    function number(v) { return String(Math.round(v * 1000) / 1000) }

    function render(all)
    {
        const lines = [];
        for (const name of Object.keys(all).sort())
        {
            const d = all[name];
            lines.push("", "output " + Kdl.quote(name) + " {");
            if (d.enabled === false) lines.push("    off");
            else
            {
                if (d.mode) lines.push("    mode " + Kdl.quote(d.mode));
                lines.push("    scale " + number(d.scale || 1));
                lines.push("    transform " + Kdl.quote(d.transform || "normal"));
                if (d.position) lines.push("    position x=" + Math.round(d.position.x) + " y=" + Math.round(d.position.y));
                if (d.vrr === "on") lines.push("    variable-refresh-rate");
                else if (d.vrr === "on-demand") lines.push("    variable-refresh-rate on-demand=true");
            }
            lines.push("}");
        }
        return lines.join("\n");
    }

    function write(all)
    {
        if (writer.busy) { writeAgain.restart(); return; }
        error = "";
        writer.run(helper.concat(["write", "07-user-output.kdl", render(all)]));
    }
    Timer { id: writeAgain; interval: 200; onTriggered: serviceDisplay.write(Config.displays || {}) }

    CommandProcess
    {
        id: writer
        onCompleted: code =>
        {
            if (code !== 0) serviceDisplay.error = writer.errorMessage(Tr.tr("service.display.saveFailed"));
            refreshSoon.restart();
        }
    }

    Timer { id: refreshSoon; interval: 600; onTriggered: serviceDisplay.refresh() }

    Process
    {
        id: reader
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                try
                {
                    const all = JSON.parse(text);
                    serviceDisplay.outputs = Object.keys(all).sort().map(k => all[k]);
                    serviceDisplay.loaded = true;
                }
                catch (e) { serviceDisplay.error = Tr.tr("service.display.readFailed") }
            }
        }
    }

    property string brightnessDevice: ""
    property int    brightnessMax: 0
    property real   brightness: 0
    property string brightnessStatus: ""
    property int    brightnessPending: -1
    property int    brightnessRunning: -1
    property int    brightnessApplied: -1

    readonly property bool brightnessAvailable: brightnessDevice !== "" && brightnessMax > 0

    function setBrightness(value)
    {
        if (!brightnessAvailable || !Number.isFinite(Number(value))) return;
        brightnessPending = Math.max(1, Math.min(100, Math.round(Number(value) * 100)));
        brightnessStatus = "";
        brightnessDebounce.restart();
    }

    Process
    {
        running: true
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do if [ -d \"$d\" ]; then printf '%s\\n' \"$d\"; break; fi; done"]
        stdout: StdioCollector { onStreamFinished: serviceDisplay.brightnessDevice = text.trim() }
    }

    FileView
    {
        path: serviceDisplay.brightnessDevice !== "" ? serviceDisplay.brightnessDevice + "/max_brightness" : ""
        onLoaded: { const v = parseInt(text()); if (!isNaN(v)) serviceDisplay.brightnessMax = v }
    }

    FileView
    {
        id: brightnessCurrent
        path: serviceDisplay.brightnessDevice !== "" ? serviceDisplay.brightnessDevice + "/brightness" : ""
        onLoaded:
        {
            const v = parseInt(text());
            if (!isNaN(v) && serviceDisplay.brightnessMax > 0) serviceDisplay.brightness = Math.max(0, Math.min(1, v / serviceDisplay.brightnessMax));
        }
    }

    CommandProcess
    {
        id: brightnessSetter
        stdout: StdioCollector { onStreamFinished: { const m = text.trim(); if (m.length > 0) serviceDisplay.brightnessStatus = m } }
        onCompleted: function(exitCode)
        {
            if (exitCode === 0)
            {
                serviceDisplay.brightnessApplied = serviceDisplay.brightnessRunning;
                brightnessRefresh.restart();
                if (serviceDisplay.brightnessPending !== serviceDisplay.brightnessApplied) brightnessDebounce.restart();
            }
            else
            {
                serviceDisplay.brightnessStatus = brightnessSetter.errorMessage(Tr.tr("service.display.brightnessFailed").arg(exitCode));
                serviceDisplay.brightnessPending = serviceDisplay.brightnessApplied;
            }
        }
    }

    Timer
    {
        id: brightnessDebounce
        interval: 100
        onTriggered:
        {
            if (brightnessSetter.busy) { restart(); return; }
            if (serviceDisplay.brightnessPending < 1 || serviceDisplay.brightnessPending === serviceDisplay.brightnessApplied) return;
            serviceDisplay.brightnessRunning = serviceDisplay.brightnessPending;
            const deviceName = serviceDisplay.brightnessDevice.substring(serviceDisplay.brightnessDevice.lastIndexOf("/") + 1);

            brightnessSetter.run(["brightnessctl", "--quiet", "--device=" + deviceName, "set", serviceDisplay.brightnessRunning + "%"]);
        }
    }

    Timer
    {
        interval: 1000
        repeat: true
        running: serviceDisplay.brightnessAvailable
        onTriggered: brightnessCurrent.reload()
    }

    Timer { id: brightnessRefresh; interval: 120; onTriggered: brightnessCurrent.reload() }

    readonly property int nightLightMode: Config.nightLightMode
    readonly property int nightLightTemperature: Math.max(1000, Math.min(6400, Config.nightLightTemperature))
    readonly property int nightLightDay: 6500

    property bool   nightLightInstalled: true
    property string nightLightError: ""

    function validTime(s) { return /^([01]?\d|2[0-3]):[0-5]\d$/.test(String(s).trim()) }

    readonly property bool nightLightHoursSet: validTime(Config.nightLightFrom) && validTime(Config.nightLightTo)

    readonly property var nightLightArgs:
    {
        const t = String(nightLightTemperature);
        switch (nightLightMode)
        {
            case 1: return ["-t", t, "-T", String(nightLightTemperature + 1)];
            case 2: return nightLightHoursSet ? ["-t", t, "-T", String(nightLightDay), "-s", Config.nightLightFrom.trim(), "-S", Config.nightLightTo.trim(), "-d", "1800"] : [];
        }
        return [];
    }
    readonly property bool nightLightWanted: nightLightArgs.length > 0 && Config.initialized

    function minutes(s) { const [h, m] = String(s).trim().split(":").map(n => parseInt(n, 10)); return h * 60 + m }
    function nightLightActiveAt(date)
    {
        if (nightLightMode === 1) return true;
        if (nightLightMode !== 2 || !nightLightHoursSet) return false;
        const now = date.getHours() * 60 + date.getMinutes();
        const from = minutes(Config.nightLightFrom), to = minutes(Config.nightLightTo);
        return from <= to ? now >= from && now < to : now >= from || now < to;
    }

    property int nightLightLastMode: 1
    onNightLightModeChanged: if (nightLightMode > 0) nightLightLastMode = nightLightMode
    function toggleNightLight() { Config.set("nightLightMode", nightLightMode === 0 ? nightLightLastMode : 0) }

    onNightLightArgsChanged: sunsetRestart.restart()
    onNightLightWantedChanged: sunsetRestart.restart()

    readonly property string sunsetGuard: "wlsunset \"$@\" & child=$!; parent=$PPID; "
        + "trap 'kill $child 2>/dev/null' TERM INT HUP; "
        + "while kill -0 $parent 2>/dev/null && kill -0 $child 2>/dev/null; do sleep 1; done; "
        + "kill $child 2>/dev/null; wait $child"

    property bool sunsetStopping: false

    function sunsetStart()
    {
        nightLightError = "";
        if (!nightLightWanted || !nightLightInstalled) return;
        sunset.command = ["sh", "-c", serviceDisplay.sunsetGuard, "night-light"].concat(nightLightArgs);
        sunset.running = true;
    }

    Timer
    {
        id: sunsetRestart
        interval: 300
        onTriggered:
        {
            if (sunset.running) { serviceDisplay.sunsetStopping = true; sunset.running = false; }
            else serviceDisplay.sunsetStart();
        }
    }

    Process
    {
        id: sunset

        stderr: StdioCollector { id: sunsetComplaint }
        onExited: code =>
        {
            if (serviceDisplay.sunsetStopping) { serviceDisplay.sunsetStopping = false; serviceDisplay.sunsetStart(); return; }
            const message = sunsetComplaint.text.trim().split("\n").pop();
            serviceDisplay.nightLightError = message !== "" ? message : Tr.tr("service.display.nightLightFailed").arg(code);
        }
    }

    Process
    {
        running: true
        command: ["sh", "-c", "command -v wlsunset"]
        onExited: code => { serviceDisplay.nightLightInstalled = code === 0; if (serviceDisplay.nightLightInstalled) sunsetRestart.restart() }
    }

    IpcHandler
    {
        target: "nightlight"
        function toggle(): void { serviceDisplay.toggleNightLight() }
        function on(): void { Config.set("nightLightMode", 1) }
        function off(): void { Config.set("nightLightMode", 0) }
    }
}
