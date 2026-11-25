pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: serviceColors

    readonly property string wallpaper: Config.themeAccent || Config.kittyColorsEnabled
        ? ServiceAppearance.wallpaperImage || "" : ""
    readonly property string paletteRequest: Config.initialized && wallpaper
        ? JSON.stringify([wallpaper, ServiceAppearance.wallpaperRevision ?? 0]) : ""
    property var paletteResult: ({key: "", palettes: {}, error: ""})
    readonly property string sourceColor: paletteResult.palettes.dark?.source_color ?? ""
    readonly property string paletteError: paletteResult.key === paletteRequest ? paletteResult.error : ""
    readonly property bool needsPalette: paletteRequest !== "" && (paletteResult.key !== paletteRequest || paletteError !== "")

    readonly property var kittyCommand:
    {
        if (!Config.initialized) return [];
        if (!Config.kittyColorsEnabled) return ["kitty", "clear"];
        const mode = ServiceAppearance.effectiveThemeStyle === Enums.ThemeLight ? "light" : "dark";
        const palette = paletteResult.key === paletteRequest ? paletteResult.palettes[mode] : null;
        return palette ? ["kitty", "apply", JSON.stringify(palette)] : [];
    }
    readonly property string kittyRequest: kittyCommand.length ? JSON.stringify(kittyCommand) : ""
    property string kittyWriteError: ""
    readonly property string kittyError: kittyWriteError || (Config.kittyColorsEnabled
        ? paletteError || (wallpaper ? "" : "wallpaperMissing") : "")
    readonly property string automaticColorHint: Tr.tr(Config.themeAccent && paletteError
        ? "service.colors." + paletteError : "settings.appearance.automaticColorHint")

    function refresh()
    {
        if (needsPalette) paletteTimer.restart();
        if (kittyRequest) kittyTimer.restart();
    }

    function response(code, output)
    {
        if (code === 0)
        {
            try { return JSON.parse(output) || {}; }
            catch (error) { }
        }
        return {};
    }

    onPaletteRequestChanged: if (paletteRequest) paletteTimer.restart()
    onKittyRequestChanged:
    {
        kittyWriteError = "";
        if (kittyRequest) kittyTimer.restart();
    }
    Component.onCompleted: refresh()

    Timer
    {
        id: paletteTimer
        interval: 140
        onTriggered:
        {
            if (generator.busy || !serviceColors.needsPalette) return;
            generator.job = serviceColors.paletteRequest;
            generator.run(Paths.commandFor("colors", ["generate", serviceColors.wallpaper]));
        }
    }
    CommandProcess
    {
        id: generator
        property string job: ""
        stdout: StdioCollector { id: paletteOutput }
        onCompleted: code =>
        {
            if (job !== serviceColors.paletteRequest)
            {
                if (serviceColors.needsPalette) paletteTimer.restart();
                return;
            }
            const data = serviceColors.response(code, paletteOutput.text);
            serviceColors.paletteResult = {key: job, palettes: data.palettes || {}, error: data.error ?? "wallpaperFailed"};
        }
    }

    Timer
    {
        id: kittyTimer
        interval: 0
        onTriggered:
        {
            if (writer.busy || !serviceColors.kittyRequest) return;
            writer.job = serviceColors.kittyRequest;
            writer.run(Paths.commandFor("colors", serviceColors.kittyCommand));
        }
    }
    CommandProcess
    {
        id: writer
        property string job: ""
        stdout: StdioCollector { id: kittyOutput }
        onCompleted: code =>
        {
            if (job !== serviceColors.kittyRequest)
            {
                if (serviceColors.kittyRequest) kittyTimer.restart();
                return;
            }
            serviceColors.kittyWriteError = serviceColors.response(code, kittyOutput.text).error ?? "kittyFailed";
        }
    }
}
