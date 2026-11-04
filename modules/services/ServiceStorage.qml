pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../components"
import "../core"
import "../src/ModelSync.js" as ModelSync

Singleton
{
    id: serviceStorage

    property int watchers: 0
    readonly property bool watching: watchers > 0
    onWatchingChanged: if (watching) refresh()

    ListModel { id: volumeItems }
    readonly property alias volumeModel: volumeItems
    property var volumes: []
    property bool volumesLoaded: false
    property var devices: []
    property bool devicesLoaded: false
    property string error: ""
    property string message: ""
    readonly property bool loading: volumesReader.busy || devicesReader.busy
    readonly property bool busy: mountWriter.busy || validatingRequest !== null
    property string udisksCommand: ""
    property string pkexecCommand: ""
    property bool pythonAvailable: false
    readonly property bool persistentAvailable: pkexecCommand !== "" && pythonAvailable
    readonly property string helper: Paths.shellDir + "/scripts/storage"
    property string mountMode: "once"
    property string mountPoint: ""
    property string activeMode: "once"
    property var startupMounts: []
    property string selectedPath: ""
    readonly property var selectedDevice: devices.find(d => d.path === selectedPath) || null
    readonly property var availableDevices: devices.filter(d => !d.mounted)
    property var validatingRequest: null
    property var pending: null
    readonly property bool confirming: pending !== null

    function size(bytes)
    {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let value = Number(bytes) || 0, index = 0;
        while (value >= 1000 && index < units.length - 1) { value /= 1000; index++; }
        return (value >= 100 || index === 0 ? Math.round(value) : value.toFixed(1)) + " " + units[index];
    }

    function refresh(probeTools)
    {
        if (busy) return;
        volumesReader.run(["findmnt", "--df", "--json", "--bytes", "--output", "SOURCE,FSTYPE,SIZE,USED,AVAIL,TARGET"]);
        readDevices();
        if (probeTools !== false && !toolsProbe.running) toolsProbe.running = true;
    }

    function readDevices()
    {
        return devicesReader.run(["lsblk", "--json", "--bytes", "--paths", "--output", "NAME,TYPE,FSTYPE,LABEL,UUID,SIZE,MOUNTPOINTS,RO,RM,MODEL,TRAN"]);
    }

    function parseVolumes(text)
    {
        const excluded = ["tmpfs", "devtmpfs", "efivarfs", "overlay", "squashfs", "ramfs"];
        const rows = [];
        function visit(list)
        {
            for (const item of list)
            {
                if (Number(item.size) > 0 && !excluded.includes(item.fstype)) rows.push({
                    device: item.source || "", type: item.fstype || "", size: Number(item.size),
                    used: Number(item.used) || 0, free: Number(item.avail) || 0, target: item.target || ""
                });
                if (Array.isArray(item.children)) visit(item.children);
            }
        }
        const data = JSON.parse(text);
        if (!Array.isArray(data.filesystems)) throw new Error("Missing filesystems");
        visit(data.filesystems);
        return rows.sort((a, b) => a.target === "/" ? -1 : b.target === "/" ? 1 : a.target.localeCompare(b.target));
    }

    function parseDevices(text)
    {
        const excluded = ["swap", "crypto_luks", "bitlocker", "lvm2_member", "linux_raid_member", "zfs_member", "squashfs"];
        const seen = {}, result = [];
        function visit(list, parentModel)
        {
            for (const item of list)
            {
                const model = String(item.model || parentModel || "").trim();
                const path = String(item.name || "");
                const filesystem = String(item.fstype || "");
                if (path.startsWith("/dev/") && filesystem !== "" && !excluded.includes(filesystem.toLowerCase()) && item.type !== "loop" && !seen[path])
                {
                    const targets = (Array.isArray(item.mountpoints) ? item.mountpoints : []).filter(p => typeof p === "string" && p.startsWith("/"));
                    result.push({ path: path, label: String(item.label || ""), uuid: String(item.uuid || ""),
                        filesystem: filesystem, size: Number(item.size) || 0, model: model,
                        readOnly: item.ro === true || item.ro === 1 || item.ro === "1",
                        mounted: targets.length > 0, targets: targets });
                    seen[path] = true;
                }
                if (Array.isArray(item.children)) visit(item.children, model);
            }
        }
        const data = JSON.parse(text);
        if (!Array.isArray(data.blockdevices)) throw new Error("Missing blockdevices");
        visit(data.blockdevices, "");
        return result.sort((a, b) => a.path.localeCompare(b.path));
    }

    function deviceLabel(device)
    {
        const name = device.label || device.model;
        return (name ? name + " · " : "") + device.path + " · " + size(device.size) + " · " + device.filesystem;
    }

    function selectDevice(path)
    {
        if (busy) return;
        pending = null;
        selectedPath = path;
        const device = devices.find(d => d.path === path);
        const name = device ? (device.label || device.uuid || device.path.split("/").pop()).replace(/[^a-zA-Z0-9_-]+/g, "-").replace(/^-+|-+$/g, "") : "";
        mountPoint = name !== "" ? "/mnt/" + name : "";
        error = "";
        message = "";
    }

    function setMountMode(mode)
    {
        if (busy || !["once", "persistent"].includes(mode)) return;
        pending = null;
        mountMode = mode;
        error = "";
    }

    function setMountPoint(value)
    {
        if (busy) return;
        pending = null;
        mountPoint = value;
        error = "";
    }

    function parseStartupMounts(text)
    {
        function decode(value) { return value.replace(/\\(040|011|012|134)/g, (_, code) => String.fromCharCode(parseInt(code, 8))) }
        return text.split("\n").filter(l => l.trim() !== "" && !l.trim().startsWith("#")).map(line =>
        {
            const fields = line.trim().split(/\s+/);
            return { source: decode(fields[0] || ""), target: decode(fields[1] || ""), options: fields[3] || "" };
        });
    }

    function mountError(device, mode, target)
    {
        if (!device || device.mounted) return Tr.tr("service.storage.selectUnmounted");
        if (!["once", "persistent"].includes(mode)) return Tr.tr("service.storage.invalidMode");
        if (mode === "once") return udisksCommand ? "" : Tr.tr("service.storage.udisksMissing");
        if (!persistentAvailable) return Tr.tr("service.storage.persistentToolsMissing");
        if (!device.uuid || !/^[A-Za-z0-9-]+$/.test(device.uuid)) return Tr.tr("service.storage.uuidRequired");
        if (devices.filter(d => d.uuid === device.uuid).length !== 1) return Tr.tr("service.storage.duplicateUuid");
        if (!/^\/(mnt|media)\/[^/]+$/.test(target) || /[\x00-\x1f\x7f\\]/.test(target) || [".", ".."].includes(target.split("/").pop())) return Tr.tr("service.storage.invalidMountPoint");
        if (startupMounts.some(m => m.source === "UUID=" + device.uuid || m.source === device.path)) return Tr.tr("service.storage.alreadyConfigured");
        if (startupMounts.some(m => m.target === target)) return Tr.tr("service.storage.mountPointInUse");
        return "";
    }

    function prepareMount()
    {
        if (busy || loading) return;
        const device = selectedDevice;
        error = "";
        message = "";
        const target = mountPoint.trim();
        error = mountError(device, mountMode, target);
        if (error !== "") { pending = null; return; }
        pending = { path: device.path, uuid: device.uuid, filesystem: device.filesystem,
            label: deviceLabel(device), readOnly: device.readOnly, mode: mountMode, target: target };
    }

    function cancelMount() { if (!busy) pending = null }

    function confirmMount()
    {
        if (busy || loading || !pending) return;
        validatingRequest = pending;
        pending = null;
        readDevices();
    }

    function executeMount(request)
    {
        validatingRequest = null;
        const device = devices.find(d => d.path === request.path);
        if (!device || device.mounted || device.uuid !== request.uuid || device.filesystem !== request.filesystem)
        {
            error = Tr.tr("service.storage.deviceChanged");
            refresh();
            return;
        }
        error = mountError(device, request.mode, request.target);
        if (error !== "") return;
        activeMode = request.mode;
        if (request.mode === "persistent")
        {
            mountWriter.run([pkexecCommand, helper, "mount", request.path, request.uuid, request.filesystem, request.target]);
            return;
        }
        const command = [udisksCommand, "mount", "--block-device", device.path];
        if (device.readOnly) command.push("--options", "ro");
        mountWriter.run(command);
    }

    CommandProcess
    {
        id: volumesReader
        stdout: StdioCollector { id: volumeOutput }
        onCompleted: code =>
        {
            if (code !== 0) { serviceStorage.error = errorMessage(Tr.tr("service.storage.readVolumesFailed")); return; }
            try
            {
                const next = serviceStorage.parseVolumes(volumeOutput.text);
                ModelSync.sync(volumeItems, next, "target");
                if (JSON.stringify(next) !== JSON.stringify(serviceStorage.volumes)) serviceStorage.volumes = next;
                serviceStorage.volumesLoaded = true;
            }
            catch (e) { serviceStorage.error = Tr.tr("service.storage.readVolumesFailed") }
        }
    }

    CommandProcess
    {
        id: devicesReader
        stdout: StdioCollector { id: deviceOutput }
        onCompleted: code =>
        {
            if (code !== 0) { serviceStorage.validatingRequest = null; serviceStorage.error = errorMessage(Tr.tr("service.storage.readDevicesFailed")); return; }
            try
            {
                const next = serviceStorage.parseDevices(deviceOutput.text);
                if (JSON.stringify(next) !== JSON.stringify(serviceStorage.devices)) serviceStorage.devices = next;
                serviceStorage.devicesLoaded = true;
                if (serviceStorage.selectedPath !== "" && !serviceStorage.devices.some(d => d.path === serviceStorage.selectedPath)) serviceStorage.cancelMount();
                if (serviceStorage.validatingRequest) serviceStorage.executeMount(serviceStorage.validatingRequest);
            }
            catch (e) { serviceStorage.validatingRequest = null; serviceStorage.error = Tr.tr("service.storage.readDevicesFailed") }
        }
    }

    Process
    {
        id: toolsProbe
        command: ["sh", "-c", 'for name in udisksctl pkexec python3; do path=$(command -v "$name" 2>/dev/null || true); printf "%s=%s\\n" "$name" "$path"; done']
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const paths = {};
                for (const line of text.split("\n")) { const i = line.indexOf("="); if (i > 0) paths[line.substring(0, i)] = line.substring(i + 1); }
                serviceStorage.udisksCommand = paths.udisksctl || "";
                serviceStorage.pkexecCommand = paths.pkexec || "";
                serviceStorage.pythonAvailable = !!paths.python3;
            }
        }
    }

    CommandProcess
    {
        id: mountWriter
        onCompleted: code =>
        {
            if (code === 0) serviceStorage.message = serviceStorage.activeMode === "persistent" ? Tr.tr("service.storage.mountedPersistent") : Tr.tr("service.storage.mountedOnce");
            else serviceStorage.error = code === 126 ? Tr.tr("service.storage.authorizationCancelled") : errorMessage(Tr.tr("service.storage.mountFailed"));
            Qt.callLater(() => serviceStorage.refresh());
        }
    }

    FileView
    {
        id: startupFile
        path: "/etc/fstab"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: serviceStorage.startupMounts = serviceStorage.parseStartupMounts(text())
        onLoadFailed: serviceStorage.startupMounts = []
    }

    Process
    {
        running: serviceStorage.watching
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]
        stdout: SplitParser { onRead: line => { if (/\b(add|remove|change)\b/.test(line)) refreshSoon.restart() } }
    }

    Timer { id: refreshSoon; interval: 500; onTriggered: serviceStorage.refresh(false) }
    Timer { interval: 10000; running: serviceStorage.watching; repeat: true; onTriggered: serviceStorage.refresh(false) }
}
