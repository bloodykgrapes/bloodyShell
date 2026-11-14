pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: serviceKeyboard

    readonly property string file: ServiceCompositor.configFiles.input || ""
    readonly property var helper: ServiceCompositor.configuration([])

    property var    layouts: []
    property string switchOption: ""
    property string capsOption: ""
    property var    otherOptions: []
    property int    repeatDelay: 600
    property int    repeatRate: 25
    property string trackLayout: "global"
    property bool   numlock: false

    property bool   loaded: false
    property string error: ""
    readonly property bool busy: flush.running || writer.busy

    property var catalog: []
    property var variants: ({})

    function layoutName(code)
    {
        const found = catalog.find(l => l.code === code);
        return found ? found.name : code;
    }
    function variantName(code, variant)
    {
        if (!variant) return "";
        const found = (variants[code] || []).find(v => v.code === variant);
        return found ? found.name : variant;
    }
    function title(entry) { return entry.variant ? variantName(entry.layout, entry.variant) : layoutName(entry.layout) }

    function refresh() { store.reload() }

    function addLayout(layout, variant)
    {
        if (!layout || layouts.some(l => l.layout === layout && l.variant === (variant || ""))) return;
        layouts = layouts.concat([{ layout: layout, variant: variant || "" }]);
        save();
    }
    function removeLayout(index)
    {
        if (layouts.length <= 1) return;
        const next = layouts.slice();
        next.splice(index, 1);
        layouts = next;
        save();
    }

    function moveLayout(index, delta)
    {
        const target = index + delta;
        if (target < 0 || target >= layouts.length) return;
        const next = layouts.slice();
        const [item] = next.splice(index, 1);
        next.splice(target, 0, item);
        layouts = next;
        save();
    }
    function set(key, value) { serviceKeyboard[key] = value; save() }

    function save() { if (ServiceCompositor.supports("keyboard")) { error = ""; flush.restart(); } }
    Timer { id: flush; interval: 400; onTriggered: serviceKeyboard.write() }

    function write()
    {
        if (writer.busy) { flush.restart(); return; }
        if (!ServiceCompositor.supports("keyboard")) return;
        writer.run(helper.concat(ServiceCompositor.backend.keyboardWriteArgs(serviceKeyboard)));
    }

    CommandProcess
    {
        id: writer
        onCompleted: code =>
        {
            if (code !== 0) serviceKeyboard.error = writer.errorMessage(Tr.tr("service.keyboard.saveFailed"));
            store.reload();
        }
    }

    function parse(text)
    {
        if (!ServiceCompositor.supports("keyboard")) return;
        const values = ServiceCompositor.backend.keyboardSettings(text);
        for (const key of Object.keys(values)) serviceKeyboard[key] = values[key];
        loaded = true;
    }

    FileView
    {
        id: store

        path: serviceKeyboard.file
        printErrors: false

        watchChanges: ServiceCompositor.supports("keyboard")
        onFileChanged: reload()
        onLoaded: if (!flush.running && !writer.busy) serviceKeyboard.parse(text())
        onLoadFailed: if (!flush.running && !writer.busy) serviceKeyboard.parse("")
    }

    Process
    {
        running: true
        command: ["awk", "/^! layout/ { s = \"L\"; next } /^! variant/ { s = \"V\"; next } /^!/ { s = \"\"; next } "
                  + "s == \"L\" && NF { code = $1; $1 = \"\"; sub(/^ +/, \"\"); print \"L\\t\" code \"\\t\" $0 } "
                  + "s == \"V\" && NF { code = $1; lay = $2; sub(/:$/, \"\", lay); $1 = \"\"; $2 = \"\"; sub(/^ +/, \"\"); print \"V\\t\" lay \"\\t\" code \"\\t\" $0 }",
                  "/usr/share/X11/xkb/rules/base.lst"]
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const layouts = [], variants = {};
                for (const line of text.split("\n"))
                {
                    const f = line.split("\t");
                    if (f[0] === "L" && f.length >= 3) layouts.push({ code: f[1], name: f[2] });
                    else if (f[0] === "V" && f.length >= 4) (variants[f[1]] = variants[f[1]] || []).push({ code: f[2], name: f[3] });
                }
                layouts.sort((a, b) => a.name.localeCompare(b.name));
                serviceKeyboard.catalog = layouts;
                serviceKeyboard.variants = variants;
            }
        }
    }
}
