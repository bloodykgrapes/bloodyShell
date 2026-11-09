import QtQuick
import Quickshell.Io

Process
{
    id: commandProcess

    readonly property bool busy: requested || running
    property string errorText: ""
    property bool requested: false
    property bool startedSuccessfully: false

    signal completed(int code)

    stderr: StdioCollector { id: errors }
    onStarted: startedSuccessfully = true
    onExited: (code, status) =>
    {
        errorText = errors.text.trim().split("\n").pop() || "";
        finish(status === 0 ? code : -1);
    }
    onRunningChanged:
    {
        if (!running && requested && !startedSuccessfully)
            Qt.callLater(() =>
            {
                if (commandProcess.requested && !commandProcess.running && !commandProcess.startedSuccessfully)
                    commandProcess.finish(-1);
            });
    }

    function run(args)
    {
        if (busy) return false;
        errorText = "";
        startedSuccessfully = false;
        requested = true;
        exec(args);
        return true;
    }

    function finish(code)
    {
        if (!requested) return;
        requested = false;
        completed(code);
    }

    function errorMessage(fallback) { return errorText || fallback }
}
