pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: serviceSystem

    property var release: ({})
    readonly property string distribution: release.ID || "linux"
    readonly property string logo: ServiceAppearance.iconPath(release.LOGO || distribution + "-logo")
        || ServiceAppearance.iconPath("distributor-logo") || Icon.settingsGeneral

    property bool detailsRequested: false
    readonly property bool loading: compositorVersion.busy || graphicsDevices.busy
    property string hostname: ""
    property string kernel: ""
    property string vendor: ""
    property string product: ""
    property string processor: ""
    property int threads: 0
    property real memoryKiB: 0
    property string compositor: ""
    property var graphics: []

    readonly property string device:
    {
        const junk = /to be filled|system product name|default string|not specified|^unknown$|^none$|^$/i;
        const maker = junk.test(vendor) ? "" : vendor;
        const model = junk.test(product) ? "" : product;
        return maker && model.toLowerCase().startsWith(maker.toLowerCase()) ? model : [maker, model].filter(Boolean).join(" ");
    }

    function ensureDetails() { if (!detailsRequested) refresh() }

    function refresh()
    {
        if (loading) return;
        if (!detailsRequested) detailsRequested = true;
        else for (const file of [hostFile, kernelFile, vendorFile, productFile, cpuFile, memoryFile]) file.reload();
        releaseFile.reload();
        if (ServiceCompositor.versionCommand.length > 0) compositorVersion.run(ServiceCompositor.versionCommand);
        graphicsDevices.run(["lspci", "-mm"]);
    }

    function cpuInfo(text)
    {
        const name = /^model name\s*:\s*(.+)$/mi.exec(text) || /^Hardware\s*:\s*(.+)$/m.exec(text) || /^Processor\s*:\s*(.+)$/m.exec(text);
        return { name: name ? name[1].trim().replace(/\((R|TM)\)/gi, "").replace(/\s+/g, " ") : "",
            threads: (text.match(/^processor\s*:/gm) || []).length };
    }

    function graphicsInfo(text)
    {
        const result = [];
        for (const line of text.split("\n"))
        {
            const quoted = line.match(/"(?:[^"\\]|\\.)*"/g) || [];
            const fields = quoted.map(value => value.slice(1, -1).replace(/\\(["\\])/g, "$1"));
            if (fields.length < 3 || !/^(VGA|3D|Display)/i.test(fields[0])) continue;
            const maker = /AMD|Advanced Micro/i.test(fields[1]) ? "AMD" : /NVIDIA/i.test(fields[1]) ? "NVIDIA"
                : /Intel/i.test(fields[1]) ? "Intel" : fields[1].replace(/,?\s+(Inc|Corporation|Corp|Co|Ltd)\b.*$/i, "");
            const bracket = /\[([^\]]+)\]/.exec(fields[2]);
            const model = bracket ? bracket[1] : fields[2];
            const name = model.toLowerCase().startsWith(maker.toLowerCase()) ? model : [maker, model].filter(Boolean).join(" ");
            if (!result.includes(name)) result.push(name);
        }
        return result;
    }

    FileView
    {
        id: releaseFile
        path: "/etc/os-release"
        printErrors: false
        onLoaded:
        {
            const values = {};
            for (const line of text().split("\n"))
            {
                const match = line.match(/^([A-Z_]+)=(.*)$/);
                if (!match) continue;
                values[match[1]] = match[2].trim().replace(/^["']|["']$/g, "");
            }
            serviceSystem.release = values;
        }
    }

    FileView
    {
        id: hostFile
        path: serviceSystem.detailsRequested ? "/proc/sys/kernel/hostname" : ""
        printErrors: false
        onLoaded: serviceSystem.hostname = text().trim()
        onLoadFailed: serviceSystem.hostname = ""
    }
    FileView
    {
        id: kernelFile
        path: serviceSystem.detailsRequested ? "/proc/sys/kernel/osrelease" : ""
        printErrors: false
        onLoaded: serviceSystem.kernel = text().trim()
        onLoadFailed: serviceSystem.kernel = ""
    }
    FileView
    {
        id: vendorFile
        path: serviceSystem.detailsRequested ? "/sys/class/dmi/id/sys_vendor" : ""
        printErrors: false
        onLoaded: serviceSystem.vendor = text().trim()
        onLoadFailed: serviceSystem.vendor = ""
    }
    FileView
    {
        id: productFile
        path: serviceSystem.detailsRequested ? "/sys/class/dmi/id/product_name" : ""
        printErrors: false
        onLoaded: serviceSystem.product = text().trim()
        onLoadFailed: serviceSystem.product = ""
    }
    FileView
    {
        id: cpuFile
        path: serviceSystem.detailsRequested ? "/proc/cpuinfo" : ""
        printErrors: false
        onLoaded:
        {
            const cpu = serviceSystem.cpuInfo(text());
            serviceSystem.processor = cpu.name;
            serviceSystem.threads = cpu.threads;
        }
        onLoadFailed: { serviceSystem.processor = ""; serviceSystem.threads = 0; }
    }
    FileView
    {
        id: memoryFile
        path: serviceSystem.detailsRequested ? "/proc/meminfo" : ""
        printErrors: false
        onLoaded:
        {
            const total = /^MemTotal:\s+(\d+)\s+kB/m.exec(text());
            serviceSystem.memoryKiB = total ? Number(total[1]) : 0;
        }
        onLoadFailed: serviceSystem.memoryKiB = 0
    }

    CommandProcess
    {
        id: compositorVersion
        stdout: StdioCollector { id: compositorOutput }
        onCompleted: code => serviceSystem.compositor = code === 0 ? compositorOutput.text.trim() : ""
    }
    CommandProcess
    {
        id: graphicsDevices
        stdout: StdioCollector { id: graphicsOutput }
        onCompleted: code => serviceSystem.graphics = code === 0 ? serviceSystem.graphicsInfo(graphicsOutput.text) : []
    }
}
