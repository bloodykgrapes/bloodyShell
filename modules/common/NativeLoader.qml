import QtQuick
import Quickshell.Io

import "../core"

Loader
{
    id: nativeLoader

    required property string helper
    required property string failureText
    property string error: ""
    readonly property bool busy: build.busy || status === Loader.Loading

    function load()
    {
        if (busy || status === Loader.Ready) return;
        error = "";
        build.run(Paths.commandFor(helper));
    }

    onStatusChanged: if (status === Loader.Error) error = failureText

    CommandProcess
    {
        id: build
        stdout: StdioCollector { id: result }
        onCompleted: code =>
        {
            const uri = result.text.trim();
            if (code !== 0 || !uri.startsWith("file:"))
            {
                nativeLoader.error = errorMessage(nativeLoader.failureText);
                return;
            }
            nativeLoader.error = "";
            nativeLoader.source = "";
            nativeLoader.source = uri;
        }
    }
}
