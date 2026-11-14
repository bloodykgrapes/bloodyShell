pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: serviceResources

    property var entries: []
    property var terminal: []
    property var pending: null
    property string operation: ""
    property string error: ""
    property string message: ""
    readonly property var helper: Paths.commandFor("resources")
    readonly property bool busy: probe.busy || command.busy

    onBusyChanged:
    {
        ServiceUpdate.resourcesBusy = busy;
        if (!busy) Qt.callLater(ServiceUpdate.autoUpdate);
    }

    function refresh()
    {
        if (busy || ServiceUpdate.busy) return;
        pending = null;
        error = "";
        probe.run(helper.concat(["status"]));
    }

    function request(id)
    {
        if (busy || ServiceUpdate.busy) return;
        const entry = entries.find(item => item.id === id);
        if (!entry) return;
        error = "";
        message = "";
        pending = entry;
    }

    function apply()
    {
        if (!pending || busy || ServiceUpdate.busy) return;
        const direct = pending.kind === "wallpapers" || pending.kind === "cli";
        if (!direct && terminal.length === 0)
        {
            error = Tr.tr("settings.dependencies.noTerminal");
            return;
        }
        const entry = pending;
        pending = null;
        operation = entry.id;
        error = "";
        const args = helper.concat(["import", entry.id]);
        command.run(direct ? args : terminal.concat(args, ["--wait"]));
    }

    CommandProcess
    {
        id: probe
        stdout: StdioCollector { id: catalog }
        onCompleted: code =>
        {
            if (code !== 0) { serviceResources.error = errorMessage(Tr.tr("settings.imports.loadFailed")); return; }
            try
            {
                const data = JSON.parse(catalog.text);
                serviceResources.entries = data.entries;
                serviceResources.terminal = data.terminal;
                serviceResources.error = data.error || "";
            }
            catch (error) { serviceResources.error = String(error); }
        }
    }
    CommandProcess
    {
        id: command
        onCompleted: code =>
        {
            const id = serviceResources.operation;
            serviceResources.operation = "";
            if (code !== 0) { serviceResources.error = errorMessage(Tr.tr("settings.imports.failed")); return; }
            const entry = serviceResources.entries.find(item => item.id === id);
            serviceResources.message = entry && entry.kind === "cli" ? Tr.tr("settings.imports.cliCompleted")
                : Tr.tr("settings.imports.completed").arg(entry ? entry.destination : id);
        }
    }
}
