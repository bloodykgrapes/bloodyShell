pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: service

    property var pending: ({})
    property var pointerPending: ({})
    property string error: ""
    readonly property bool busy: writer.busy || pointerWriter.busy || flush.running || pointerFlush.running
    readonly property var windowKeys:
    [
        "windowGaps", "windowCenterFocused", "windowCenterSingle", "windowOverviewSize",
        "windowRadius", "windowClipContent", "windowBorderMode", "windowBorderWidth",
        "windowBorderColor", "windowFocusColor", "windowFocusOpacity", "windowUnfocusedOpacity",
        "windowBlurBehind", "windowAnimate", "windowAnimationStyle", "windowAnimationSpeed"
    ]

    function update(key, value)
    {
        if (Config[key] === value) return;
        Config.set(key, value);
        pending = Object.assign({}, pending, { [key]: true });
        error = "";
        flush.restart();
    }

    function updatePointer(key, value)
    {
        if (Config[key] === value) return;
        Config.set(key, value);
        pointerPending = Object.assign({}, pointerPending, { [key]: true });
        error = "";
        pointerFlush.restart();
    }

    function colorFor(mode)
    {
        if (mode === Enums.ColorAccent) return Theme.accent.toString();
        if (mode === Enums.ColorGray) return Theme.light ? "#77777d" : "#8d8d93";
        return Theme.light ? "#45454b" : "#f4f4f6";
    }

    function payload()
    {
        return {
            gaps: Config.windowGaps,
            centerFocused: Config.windowCenterFocused,
            centerSingle: Config.windowCenterSingle,
            overviewSize: Config.windowOverviewSize,
            radius: Config.windowRadius,
            clip: Config.windowClipContent,
            borderMode: Config.windowBorderMode,
            borderWidth: Config.windowBorderWidth,
            borderColor: colorFor(Config.windowBorderColor),
            focusColor: colorFor(Config.windowFocusColor),
            focusOpacity: Config.windowFocusOpacity,
            unfocusedOpacity: Config.windowUnfocusedOpacity,
            blurBehind: Config.windowBlurBehind,
            animate: Config.windowAnimate,
            animationStyle: Config.windowAnimationStyle,
            animationSpeed: Config.windowAnimationSpeed
        };
    }

    function pointerPayload()
    {
        return {
            focusFollowsPointer: Config.focusFollowsPointer,
            pointerJumpsToFocus: Config.pointerJumpsToFocus
        };
    }

    function applyNow()
    {
        if (!ServiceCompositor.supports("windows")) return;
        if (Object.keys(pending).length === 0) return;
        pending = ({});
        writer.run(ServiceCompositor.configuration(["windows", JSON.stringify(payload())]));
    }

    function applyPointerNow()
    {
        if (!ServiceCompositor.supports("windows")) return;
        if (Object.keys(pointerPending).length === 0) return;
        pointerPending = ({});
        pointerWriter.run(ServiceCompositor.configuration(["pointer", JSON.stringify(pointerPayload())]));
    }

    function reapply()
    {
        if (!ServiceCompositor.supports("windows")) return;
        const values = ({});
        for (const key of windowKeys) values[key] = true;
        pending = values;
        pointerPending = ({ focusFollowsPointer: true, pointerJumpsToFocus: true });
        error = "";
        flush.restart();
        pointerFlush.restart();
    }

    Timer
    {
        id: flush
        interval: 300
        onTriggered:
        {
            if (writer.busy) { restart(); return; }
            service.applyNow();
        }
    }

    Timer
    {
        id: pointerFlush
        interval: 300
        onTriggered:
        {
            if (pointerWriter.busy) { restart(); return; }
            service.applyPointerNow();
        }
    }

    CommandProcess
    {
        id: writer
        stdout: StdioCollector { id: result }
        onCompleted: code =>
        {
            if (code !== 0) service.error = errorMessage(Tr.tr("service.layout.saveFailed"));
            else service.error = "";
        }
    }

    CommandProcess
    {
        id: pointerWriter
        stdout: StdioCollector { id: pointerResult }
        onCompleted: code =>
        {
            if (code !== 0) service.error = errorMessage(Tr.tr("service.layout.saveFailed"));
            else service.error = "";
        }
    }
}
