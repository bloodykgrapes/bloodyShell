import QtQuick
import Quickshell.Io

import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageAbout

    title: Tr.tr("common.about")
    subtitle: Tr.tr("settings.about.description")

    property var info: ({})

    function vendor(s)
    {
        if (/AMD|Advanced Micro/i.test(s)) return "AMD";
        if (/NVIDIA/i.test(s)) return "NVIDIA";
        if (/Intel/i.test(s)) return "Intel";
        return s.replace(/,? (Inc|Corporation|Corp|Co|Ltd)\.?.*$/i, "");
    }

    function graphics(lines, cpu)
    {
        const out = [];
        for (const line of lines)
        {
            const f = line.split("\t");
            if (f.length < 2) continue;
            const v = vendor(f[0]);
            const bracket = /\[([^\]]+)\]/.exec(f[1]);
            const integrated = /w\/\s*(Radeon[^,]*Graphics)/i.exec(cpu);
            if (bracket) out.push(v + " " + bracket[1].replace(new RegExp("^" + v + "\\s+"), ""));
            else if (v === "AMD" && integrated) out.push("AMD " + integrated[1]);
            else out.push(v + " " + f[1]);
        }
        return out.join(", ");
    }

    Process
    {
        running: true
        command: ["sh", "-c", `
            . /etc/os-release 2>/dev/null; echo "os=\${PRETTY_NAME:-\${NAME:-Linux}}"
            echo "kernel=$(uname -r)"
            echo "host=$(cat /proc/sys/kernel/hostname 2>/dev/null)"
            echo "vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
            echo "product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
            echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
            echo "threads=$(nproc 2>/dev/null)"
            echo "memory=$(awk '/MemTotal/ { print $2 }' /proc/meminfo)"
            echo "niri=$(niri --version 2>/dev/null | cut -d' ' -f2)"
            command -v lspci >/dev/null && lspci -mm 2>/dev/null | grep -iE '"(VGA|3D|Display)' | awk -F'"' '{ print "gpu=" $4 "\\t" $6 }'
        `]
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const info = { gpus: [] };
                for (const line of text.split("\n"))
                {
                    const eq = line.indexOf("=");
                    if (eq < 0) continue;
                    const key = line.substring(0, eq), value = line.substring(eq + 1).trim();
                    if (key === "gpu") info.gpus.push(value);
                    else info[key] = value;
                }
                pageAbout.info = info;
            }
        }
    }

    readonly property string device:
    {
        const junk = /to be filled|system product name|default string|not specified|^$/i;
        return [info.vendor, info.product].filter(s => s && !junk.test(s)).join(" ");
    }
    readonly property string cpu: info.cpu ? info.cpu.replace(/\s+w\/.*$/i, "").replace(/\s+\d+-Core Processor$/i, "") : ""
    readonly property string memory: info.memory ? (parseInt(info.memory, 10) / 1048576).toFixed(1) + " GiB" : ""

    SettingsGroup
    {
        title: Tr.tr("common.system")

        SettingsRow { visible: pageAbout.device !== ""; label: Tr.tr("settings.about.device"); valueText: pageAbout.device }
        SettingsRow { label: Tr.tr("settings.about.operatingSystem"); valueText: pageAbout.info.os || "" }
        SettingsRow { label: Tr.tr("settings.about.kernel"); valueText: pageAbout.info.kernel || "" }
        SettingsRow { label: Tr.tr("settings.about.compositor"); valueText: "niri" + (pageAbout.info.niri ? " " + pageAbout.info.niri : "") }
        SettingsRow { visible: pageAbout.cpu !== ""; label: Tr.tr("settings.about.processor"); valueText: pageAbout.cpu + (pageAbout.info.threads ? "  ·  " + Tr.tr("settings.about.threads").arg(pageAbout.info.threads) : "") }
        SettingsRow { visible: (pageAbout.info.gpus || []).length > 0; label: Tr.tr("settings.about.graphics"); valueText: pageAbout.graphics(pageAbout.info.gpus || [], pageAbout.info.cpu || "") }
        SettingsRow { visible: pageAbout.memory !== ""; label: Tr.tr("settings.about.memory"); valueText: pageAbout.memory }
        SettingsRow { label: Tr.tr("settings.about.computerName"); valueText: pageAbout.info.host || "" }
    }

    SettingsGroup
    {
        title: "bloodyShell"

        SettingsRow { label: Tr.tr("settings.about.version"); valueText: ServiceUpdate.version }
        SettingsRow
        {
            label: Tr.tr("settings.about.github")
            description: "github.com/" + ServiceUpdate.repo

            SettingsButton { text: Tr.tr("common.open"); onClicked: Qt.openUrlExternally("https://github.com/" + ServiceUpdate.repo) }
        }
    }
}
