pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: service

    readonly property var helper: Paths.commandFor("plymouth")
    readonly property bool applying: change.busy
    readonly property bool busy: probe.busy || applying
    readonly property bool applied: appliedTheme !== "" && appliedTheme === state.current
    property var state: ({ installed: false, canApply: false, current: "", themes: [] })
    property bool scanned: false
    property string appliedTheme: ""
    property string requestedTheme: ""
    property string failedTheme: ""
    property string readError: ""
    property string applyError: ""

    function refresh()
    {
        if (!busy) probe.run(helper.concat(["status"]));
    }

    function apply(theme)
    {
        if (busy || !state.canApply || !state.themes.some(entry => entry.id === theme)) return;
        appliedTheme = "";
        failedTheme = "";
        applyError = "";
        requestedTheme = theme;
        change.run(helper.concat(["apply", theme]));
    }

    function readState(text)
    {
        try
        {
            const next = JSON.parse(text);
            if (!Array.isArray(next?.themes) || typeof next.current !== "string") return false;
            if (JSON.stringify(next.themes) === JSON.stringify(state.themes)) next.themes = state.themes;
            if (appliedTheme !== next.current) appliedTheme = "";
            state = next;
            scanned = true;
            readError = "";
            return true;
        }
        catch (failure)
        {
            return false;
        }
    }

    CommandProcess
    {
        id: probe
        stdout: StdioCollector { id: statusResult }
        onCompleted: code =>
        {
            if (code !== 0 || !service.readState(statusResult.text))
                service.readError = errorMessage(Tr.tr("settings.plymouth.readFailed"));
        }
    }

    CommandProcess
    {
        id: change
        stdout: StdioCollector { id: changeResult }
        onCompleted: code =>
        {
            const theme = service.requestedTheme;
            service.requestedTheme = "";
            if (code === 0 && service.readState(changeResult.text) && service.state.current === theme)
            {
                service.appliedTheme = theme;
                return;
            }

            service.failedTheme = theme;
            service.applyError = errorMessage(Tr.tr("settings.plymouth.applyFailed"));
            // The theme can be written before the initramfs rebuild fails.
            Qt.callLater(service.refresh);
        }
    }
}
