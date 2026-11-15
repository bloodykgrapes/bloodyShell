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
    property string operationAction: ""
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

    function request(id, action = "import")
    {
        if (busy || ServiceUpdate.busy) return;
        const entry = entries.find(item => item.id === id);
        if (!entry || !["import", "clear"].includes(action)) return;
        if (action === "import" && entry.available !== true) return;
        if (action === "clear" && entry.kind !== "greeter") return;
        error = "";
        message = "";
        pending = Object.assign({}, entry, {action: action});
    }

    function apply()
    {
        if (!pending || busy || ServiceUpdate.busy) return;
        const direct = pending.kind === "wallpapers";
        if (!direct && terminal.length === 0)
        {
            error = Tr.tr("settings.dependencies.noTerminal");
            return;
        }
        const entry = pending;
        pending = null;
        operation = entry.id;
        operationAction = entry.action;
        error = "";
        const args = helper.concat([entry.action, entry.id]);
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
            const action = serviceResources.operationAction;
            serviceResources.operation = "";
            serviceResources.operationAction = "";
            if (code !== 0) { serviceResources.error = errorMessage(Tr.tr(action === "clear" ? "settings.imports.clearFailed" : "settings.imports.failed")); return; }
            const entry = serviceResources.entries.find(item => item.id === id);
            if (entry && entry.kind === "greeter") serviceResources.entries = serviceResources.entries.map(item => item.id === id ? Object.assign({}, item, {installed: action !== "clear"}) : item);
            serviceResources.message = action === "clear" ? Tr.tr("settings.imports.cleared")
                : Tr.tr("settings.imports.completed").arg(entry ? entry.destination : id);
        }
    }
}
