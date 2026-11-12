pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: serviceDependencies

    property var entries: []
    property var terminal: []
    property string error: ""
    property string operation: ""
    property var pending: null
    readonly property bool busy: probe.busy || command.busy
    readonly property var helper: Paths.commandFor("dependencies")

    function refresh(clearError = true)
    {
        if (busy) return;
        if (clearError) error = "";
        probe.run(helper.concat(["status"]));
    }

    function request(tool, remove)
    {
        if (busy) return;
        const entry = entries.find(item => item.tool === tool);
        if (!entry || !entry.supported || (remove && (!entry.removable || !entry.installed))) return;
        pending = { tool: tool, remove: remove };
    }

    function apply()
    {
        if (!pending || busy) return;
        if (terminal.length === 0)
        {
            error = Tr.tr("settings.dependencies.noTerminal");
            return;
        }
        const change = pending;
        pending = null;
        operation = change.tool;
        error = "";
        command.run(terminal.concat(helper.concat([change.remove ? "remove" : "install", change.tool])));
    }

    CommandProcess
    {
        id: probe
        stdout: StdioCollector { id: result }
        onCompleted: code =>
        {
            if (code !== 0) { serviceDependencies.error = errorMessage(Tr.tr("settings.dependencies.checkFailed")); return; }
            try
            {
                const status = JSON.parse(result.text);
                serviceDependencies.entries = status.entries;
                serviceDependencies.terminal = status.terminal;
            }
            catch (error) { serviceDependencies.error = String(error) }
        }
    }
    CommandProcess
    {
        id: command
        onCompleted: code =>
        {
            serviceDependencies.operation = "";
            if (code !== 0) serviceDependencies.error = errorMessage(Tr.tr("settings.dependencies.actionFailed"));
            Qt.callLater(() => serviceDependencies.refresh(false));
        }
    }
}
