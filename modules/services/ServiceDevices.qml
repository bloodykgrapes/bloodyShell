pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../src/Clients.js" as Clients
import "../common"
import "../core"

Singleton
{
    id: serviceDevices

    property var watchClients: []
    readonly property int watchers: watchClients.length
    readonly property bool watching: watchers > 0
    property var mouseWatchClients: []
    readonly property int mouseWatchers: mouseWatchClients.length
    readonly property bool mouseWatching: watching || mouseWatchers > 0
    onMouseWatchingChanged: if (mouseWatching && !watching) refreshMouse()
    onWatchingChanged:
    {
        if (watching) refresh();
        else refreshSoon.stop();
    }

    function setWatching(client, active)
    {
        watchClients = Clients.update(watchClients, client, active);
    }

    function setMouseWatching(client, active)
    {
        mouseWatchClients = Clients.update(mouseWatchClients, client, active);
    }

    function refresh()
    {
        usbReader.running = true;
        printersReader.running = true;
        refreshMouse();
    }

    property var mouse: ({speed: 0, profile: "adaptive", naturalScroll: false, leftHanded: false,
        scrollHorizontal: 1, scrollVertical: 1, middleEmulation: false})
    property bool mouseLoaded: false
    property bool mouseAvailable: false
    property string mouseError: ""
    property var pendingMouse: ({})
    property int mouseRevision: 0
    readonly property bool mouseBusy: mouseWriter.busy || mouseFlush.running

    function refreshMouse()
    {
        // A full-device subscription can refresh before mouseWatching's binding updates.
        if ((!watching && mouseWatchClients.length === 0) || mouseBusy) return;
        if (mouseReader.busy) { mouseReader.again = true; return; }
        mouseReader.again = false;
        mouseReader.revision = mouseRevision;
        mouseReader.run(Paths.commandFor("niri-config", ["mouse-read"]));
    }
    function receiveMouse(text)
    {
        const data = JSON.parse(text);
        mouseAvailable = data.available;
        mouse = Object.assign({}, data.mouse, pendingMouse);
        mouseLoaded = true;
    }
    function setMouse(key, value)
    {
        if (!mouseLoaded || !mouseAvailable || mouse[key] === undefined) return;
        if (typeof value === "number") value = Math.round(value * 1000) / 1000;
        if (mouse[key] === value) return;
        mouseRevision++;
        mouse = Object.assign({}, mouse, {[key]: value});
        pendingMouse = Object.assign({}, pendingMouse, {[key]: value});
        mouseError = "";
        mouseFlush.restart();
    }
    Timer
    {
        id: mouseFlush
        interval: 350
        onTriggered:
        {
            if (mouseWriter.busy) { restart(); return; }
            if (Object.keys(serviceDevices.pendingMouse).length === 0) return;
            const changes = serviceDevices.pendingMouse;
            serviceDevices.pendingMouse = {};
            mouseWriter.run(Paths.commandFor("niri-config", ["mouse", JSON.stringify(changes)]));
        }
    }
    FileView
    {
        path: Paths.niriDir + "/06-user-input.kdl"
        printErrors: false
        watchChanges: serviceDevices.mouseWatching
        onFileChanged: { reload(); serviceDevices.refreshMouse(); }
    }
    CommandProcess
    {
        id: mouseReader
        property bool again: false
        property int revision: 0
        stdout: StdioCollector { id: mouseReadResult }
        onCompleted: code =>
        {
            if (!serviceDevices.mouseBusy && revision === serviceDevices.mouseRevision)
            {
                if (code === 0)
                {
                    try
                    {
                        if (!serviceDevices.mouseAvailable) serviceDevices.mouseError = "";
                        serviceDevices.receiveMouse(mouseReadResult.text);
                    }
                    catch (error) { serviceDevices.mouseError = String(error); }
                }
                else
                {
                    serviceDevices.mouseAvailable = false;
                    serviceDevices.mouseLoaded = true;
                    serviceDevices.mouseError = errorMessage(Tr.tr("service.devices.mouseReadFailed"));
                }
            }
            if (again) serviceDevices.refreshMouse();
        }
    }
    CommandProcess
    {
        id: mouseWriter
        stdout: StdioCollector { id: mouseWriteResult }
        onCompleted: code =>
        {
            if (code === 0)
            {
                try { serviceDevices.receiveMouse(mouseWriteResult.text); }
                catch (error) { serviceDevices.mouseError = String(error); }
            }
            else
            {
                serviceDevices.mouseError = errorMessage(Tr.tr("service.devices.mouseSaveFailed"));
            }
            serviceDevices.refreshMouse();
        }
    }

    property var usb: []

    Process
    {
        id: usbReader
        command: ["sh", "-c", `
            for d in /sys/bus/usb/devices/*; do
                [ -f "$d/idVendor" ] && [ -f "$d/product" ] || continue
                [ "$(cat "$d/idVendor")" = "1d6b" ] && continue
                [ "$(cat "$d/bDeviceClass" 2>/dev/null)" = "09" ] && continue
                classes=$(cat "$d"/*:*/bInterfaceClass 2>/dev/null | sort -u | tr '\\n' ' ')
                protocols=$(cat "$d"/*:*/bInterfaceProtocol 2>/dev/null | sort -u | tr '\\n' ' ')
                printf '%s|%s|%s|%s:%s|%s|%s\\n' "$(cat "$d/product")" "$(cat "$d/manufacturer" 2>/dev/null)" "$(cat "$d/speed")" \
                    "$(cat "$d/idVendor")" "$(cat "$d/idProduct")" "$classes" "$protocols"
            done
        `]
        stdout: StdioCollector
        {
            onStreamFinished: serviceDevices.usb = text.split("\n").filter(l => l !== "").map(l =>
            {
                const f = l.split("|");
                return { product: f[0].trim(), maker: f[1].trim(), speed: f[2], id: f[3], classes: f[4].trim().split(" "), protocols: (f[5] || "").trim().split(" ") };
            })
        }
    }

    Process
    {
        running: serviceDevices.watching
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=usb"]
        stdout: SplitParser { onRead: line => { if (/\b(add|remove)\b/.test(line)) refreshSoon.restart() } }
    }
    Timer { id: refreshSoon; interval: 400; onTriggered: if (serviceDevices.watching) usbReader.running = true }

    property var    printers: []
    property string printerDefault: ""
    property string printerState: "loading"

    function setDefaultPrinter(name)
    {
        printerDefaultSetter.run(["lpoptions", "-d", name]);
    }
    CommandProcess
    {
        id: printerDefaultSetter
        onCompleted: code =>
        {
            if (code !== 0) console.warn("ServiceDevices: could not change default printer:", errorText || code);
            printersReader.running = true;
        }
    }

    function addPrinter() { Quickshell.execDetached(["sh", "-c", "command -v system-config-printer >/dev/null && exec system-config-printer || exec xdg-open http://localhost:631/admin"]) }

    Process
    {
        id: printersReader
        command: ["sh", "-c", "command -v lpstat >/dev/null || { echo state=missing; exit 0; }; "
                  + "LC_ALL=C lpstat -r 2>/dev/null | grep -q 'is running' || { echo state=stopped; exit 0; }; "
                  + "echo state=ok; LC_ALL=C lpstat -p -d 2>/dev/null"]
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const list = [];
                let state = "ok", def = "";
                for (const line of text.split("\n"))
                {
                    let m;
                    if ((m = /^state=(\w+)/.exec(line))) state = m[1];
                    else if ((m = /^printer (\S+) (?:is )?(idle|now printing|disabled)/.exec(line)))
                        list.push({ name: m[1], status: m[2] === "now printing" ? Tr.tr("service.devices.printing") : m[2] === "disabled" ? Tr.tr("service.devices.disabled") : Tr.tr("service.devices.ready") });
                    else if ((m = /^system default destination: (\S+)/.exec(line))) def = m[1];
                }
                serviceDevices.printerState = state;
                serviceDevices.printers = list;
                serviceDevices.printerDefault = def;
            }
        }
    }

    Timer { interval: 10000; running: serviceDevices.watching; repeat: true; onTriggered: printersReader.running = true }
}
