pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: serviceDependencies

    property var packages: []
    property var dependencies: []
    readonly property var entries: packages.concat(dependencies)
    property var terminal: []
    property string packagesError: ""
    property string dependenciesError: ""
    property string actionError: ""
    readonly property string error: actionError || packagesError || dependenciesError
    property string operation: ""
    property bool operationRequired: false
    property var pending: null
    readonly property bool packagesChecking: packagesProbe.busy
    readonly property bool dependenciesChecking: dependenciesProbe.busy
    readonly property bool busy: packagesChecking || dependenciesChecking || command.busy
    readonly property var helper: Paths.commandFor("dependencies")

    function checking(required) { return required ? dependenciesChecking : packagesChecking }
    function listError(required) { return required ? dependenciesError : packagesError }
    function setListError(required, message)
    {
        if (required) dependenciesError = message;
        else packagesError = message;
    }

    function refresh(required = null)
    {
        if (command.busy) return;
        for (const group of required === null ? [false, true] : [required])
        {
            if (checking(group)) continue;
            setListError(group, "");
            const probe = group ? dependenciesProbe : packagesProbe;
            probe.run(helper.concat(["status", group ? "required" : "optional"]));
        }
    }

    function request(tool, remove)
    {
        const entry = entries.find(item => item.tool === tool);
        if (command.busy || !entry || checking(entry.required) || !entry.supported
            || (remove && (entry.required || !entry.removable || !entry.installed))) return;
        actionError = "";
        pending = { tool: tool, name: entry.packages.length ? entry.packages.join(", ") : tool, remove: remove, required: entry.required };
    }

    function description(entry)
    {
        const key = "settings.packages." + entry.tool;
        const text = Tr.tr(key);
        return text === key ? entry.feature || "" : text;
    }

    function apply()
    {
        if (!pending || command.busy || checking(pending.required)) return;
        if (terminal.length === 0)
        {
            actionError = Tr.tr("settings.dependencies.noTerminal");
            return;
        }
        const change = pending;
        pending = null;
        operation = change.tool;
        operationRequired = change.required;
        actionError = "";
        command.run(terminal.concat(helper.concat([change.remove ? "remove" : "install", change.tool])));
    }

    function completeCheck(required, code, text, message)
    {
        if (code !== 0)
        {
            setListError(required, message);
            return;
        }
        try
        {
            const status = JSON.parse(text);
            if (!Array.isArray(status.entries) || !Array.isArray(status.terminal)) throw new Error("Invalid package status");
            if (required) dependencies = status.entries;
            else packages = status.entries;
            terminal = status.terminal;
        }
        catch (error) { setListError(required, String(error)) }
    }

    CommandProcess
    {
        id: packagesProbe
        stdout: StdioCollector { id: packagesResult }
        onCompleted: code => serviceDependencies.completeCheck(false, code, packagesResult.text,
            errorMessage(Tr.tr("settings.dependencies.checkFailed")))
    }

    CommandProcess
    {
        id: dependenciesProbe
        stdout: StdioCollector { id: dependenciesResult }
        onCompleted: code => serviceDependencies.completeCheck(true, code, dependenciesResult.text,
            errorMessage(Tr.tr("settings.dependencies.checkFailed")))
    }

    CommandProcess
    {
        id: command
        onCompleted: code =>
        {
            serviceDependencies.operation = "";
            if (code !== 0) serviceDependencies.actionError = errorMessage(Tr.tr("settings.dependencies.actionFailed"));
            const required = serviceDependencies.operationRequired;
            Qt.callLater(() => serviceDependencies.refresh(required));
        }
    }
}
