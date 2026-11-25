import QtQuick
import Quickshell
import Quickshell.Io

Scope
{
    id: ipc

    required property string path
    property bool subscribed: false
    property int reconnectDelay: 500
    property var queue: []
    property var pending: null
    signal eventReceived(var message)

    function write(socket, message)
    {
        socket.write(JSON.stringify(message) + "\n");
        socket.flush();
    }

    function parse(line)
    {
        try { return JSON.parse(line); }
        catch (_) { return null; }
    }

    function reconnect()
    {
        if (!path || reconnectTimer.running) return;
        const wasSubscribed = subscribed;
        subscribed = false;
        eventTimeout.stop();
        reconnectTimer.interval = reconnectDelay;
        reconnectDelay = Math.min(8000, reconnectDelay * 2);
        reconnectTimer.start();
        events.connected = false;
        if (wasSubscribed) disconnectRequests("Compositor disconnected");
    }

    Timer { id: reconnectTimer; onTriggered: ipc.connectEvents() }
    Timer { id: eventTimeout; interval: 2000; onTriggered: ipc.reconnect() }

    function connectEvents()
    {
        if (!path || events.connected) return;
        eventTimeout.restart();
        events.connected = true;
    }

    Component.onCompleted: connectEvents()

    Socket
    {
        id: events
        path: ipc.path
        onConnectionStateChanged:
        {
            if (connected) ipc.write(events, "EventStream");
            else Qt.callLater(ipc.reconnect);
        }
        onError: Qt.callLater(ipc.reconnect)

        parser: SplitParser
        {
            onRead: line =>
            {
                const message = ipc.parse(line);
                if (ipc.subscribed)
                {
                    if (message) ipc.eventReceived(message);
                }
                else if (message?.Ok === "Handled")
                {
                    eventTimeout.stop();
                    ipc.reconnectDelay = 500;
                    ipc.subscribed = true;
                }
                else Qt.callLater(ipc.reconnect);
            }
        }
    }

    // Requests on this socket are ordered. The event subscription uses its own connection.
    function request(messages, complete = null)
    {
        if (!path || queue.length >= 64) return false;
        queue.push({ messages: messages, next: 0, complete: complete });
        sendNext();
        return true;
    }

    function sendNext()
    {
        if (pending || !queue.length) return;
        pending = queue.shift();
        requestTimeout.restart();
        if (requests.connected) writeNext();
        else requests.connected = true;
    }

    function writeNext()
    {
        if (!pending) return;
        requestTimeout.restart();
        write(requests, pending.messages[pending.next++]);
    }

    function complete(entry, result, error)
    {
        if (entry.complete) entry.complete(result, error);
        else if (error) console.warn("Niri IPC:", error);
    }

    function disconnectRequests(error)
    {
        if (!pending) return;
        const unsent = [pending].concat(queue);
        pending = null;
        queue = [];
        requestTimeout.stop();
        requests.connected = false;
        // A lost response does not tell us whether Niri performed the action.
        for (const entry of unsent) complete(entry, null, error);
    }

    function requestDisconnected()
    {
        disconnectRequests("Request socket disconnected");
    }

    Timer
    {
        id: requestTimeout
        interval: 2000
        onTriggered: ipc.disconnectRequests("Request timed out")
    }

    Socket
    {
        id: requests
        path: ipc.path
        onConnectionStateChanged:
        {
            if (connected) ipc.writeNext();
            else Qt.callLater(ipc.requestDisconnected);
        }
        // Leave the socket's own error and disconnect handlers before closing it.
        onError: Qt.callLater(ipc.requestDisconnected)

        parser: SplitParser
        {
            onRead: line =>
            {
                const entry = ipc.pending;
                if (!entry) return;
                const message = ipc.parse(line);
                if (message?.Ok === undefined && typeof message?.Err !== "string")
                {
                    Qt.callLater(ipc.disconnectRequests, "Invalid response");
                    return;
                }
                if (!message.Err && entry.next < entry.messages.length) { ipc.writeNext(); return; }

                requestTimeout.stop();
                ipc.pending = null;
                ipc.complete(entry, message.Ok ?? null, message.Err || "");
                ipc.sendNext();
            }
        }
    }
}
