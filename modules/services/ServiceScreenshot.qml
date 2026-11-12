pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: screenshot

    property string phase: "idle"
    property var capture: null
    property string output: ""
    property string error: ""
    property bool cancelled: false
    property bool saving: false
    readonly property bool active: capture !== null && phase !== "idle" && phase !== "capturing" && !cancelled
    readonly property bool busy: phase !== "idle"
    readonly property bool working: phase === "publishing"
    readonly property var helper: Paths.commandFor("screenshot")
    signal finished(bool saved, string path)

    function start(name = "", mode = -1)
    {
        if (busy || !Config.initialized || ServiceLock.locked || OverlayState.inhibited) return;
        const screen = Quickshell.screens.find(screen => screen.name === (name || ServiceCompositor.focusedOutput)) || Quickshell.screens[0];
        if (!screen) return;
        if (mode === Enums.ScreenshotArea || mode === Enums.ScreenshotScreen) Config.set("screenshotMode", mode);
        output = screen.name;
        error = "";
        cancelled = false;
        phase = "capturing";
        const display = ServiceDisplay.output(screen.name);
        const scale = display && display.logical ? display.logical.scale : screen.devicePixelRatio || 1;
        grabber.run(helper.concat(["capture", output, String(screen.width), String(screen.height), String(scale)]));
    }

    function cleanup(directory) { if (directory) Quickshell.execDetached(helper.concat(["cleanup", directory])) }
    function reset()
    {
        const directory = capture ? capture.directory : "";
        phase = "idle";
        capture = null;
        cancelled = false;
        cleanup(directory);
    }
    function cancel()
    {
        if (phase === "capturing" || phase === "publishing") { cancelled = true; return; }
        reset();
    }
    function pixels(rect, width, height)
    {
        if (!capture || width <= 0 || height <= 0) return Qt.rect(0, 0, 0, 0);
        const left = Math.max(0, Math.min(capture.width, Math.round(rect.x * capture.width / width)));
        const top = Math.max(0, Math.min(capture.height, Math.round(rect.y * capture.height / height)));
        const right = Math.max(left, Math.min(capture.width, Math.round((rect.x + rect.width) * capture.width / width)));
        const bottom = Math.max(top, Math.min(capture.height, Math.round((rect.y + rect.height) * capture.height / height)));
        return Qt.rect(left, top, right - left, bottom - top);
    }
    function submit(rect, width, height)
    {
        if (phase !== "ready") return;
        const region = pixels(rect, width, height);
        if (region.width < 1 || region.height < 1) return;
        error = "";
        saving = Config.screenshotSave;
        phase = "publishing";
        publisher.run(helper.concat(["export", capture.directory, saving ? "save" : "copy",
            String(region.x), String(region.y), String(region.width), String(region.height)]));
    }

    CommandProcess
    {
        id: grabber
        stdout: StdioCollector { id: snapshot }
        onCompleted: code =>
        {
            if (code === 0)
            {
                try
                {
                    const image = JSON.parse(snapshot.text);
                    if (!image.directory || !image.image || image.width <= 0 || image.height <= 0) throw new Error("Invalid capture");
                    screenshot.capture = image;
                    if (screenshot.cancelled || ServiceLock.locked) { screenshot.reset(); return; }
                    screenshot.phase = "ready";
                    return;
                }
                catch (error) { console.warn("Screenshot: " + error) }
            }
            screenshot.error = errorMessage(Tr.tr("screenshot.captureFailed"));
            const cancelled = screenshot.cancelled;
            screenshot.reset();
            if (!cancelled) ServiceOSD.show("screenshot", Icon.wallpapers, Tr.tr("screenshot.captureFailed"), -1, false, true, screenshot.error);
        }
    }
    CommandProcess
    {
        id: publisher
        stdout: StdioCollector { id: published }
        onCompleted: code =>
        {
            if (screenshot.cancelled || ServiceLock.locked) { screenshot.reset(); return; }
            if (code !== 0)
            {
                screenshot.error = errorMessage(Tr.tr("screenshot.exportFailed"));
                screenshot.phase = "ready";
                return;
            }
            let path = "";
            try { path = JSON.parse(published.text).path || "" } catch (error) { }
            const saved = screenshot.saving;
            screenshot.reset();
            screenshot.finished(saved, path);
            ServiceOSD.show("screenshot", Icon.wallpapers, Tr.tr(saved ? "screenshot.saved" : "screenshot.copied"), -1, false, true, path);
        }
    }

    Connections { target: ServiceLock; function onLockedChanged() { if (ServiceLock.locked) screenshot.cancel() } }
    Component.onDestruction: if (capture) cleanup(capture.directory)
}
