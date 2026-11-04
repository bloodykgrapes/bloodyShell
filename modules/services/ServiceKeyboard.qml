pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../components"
import "../core"
import "../src/Kdl.js" as Kdl

Singleton
{
    id: serviceKeyboard

    readonly property string file: Paths.niriDir + "/01-input.kdl"
    readonly property string helper: Paths.niriHelper

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

    function save() { error = ""; flush.restart() }
    Timer { id: flush; interval: 400; onTriggered: serviceKeyboard.write() }

    function renderBlock(indent)
    {
        const i1 = indent, i2 = indent + "    ", i3 = indent + "        ";
        const options = [switchOption, capsOption].concat(otherOptions).filter(o => o !== "");
        const lines = [i1 + "keyboard {", i2 + "xkb {"];
        lines.push(i3 + "layout " + Kdl.quote(layouts.map(l => l.layout).join(",")));
        if (layouts.some(l => l.variant !== "")) lines.push(i3 + "variant " + Kdl.quote(layouts.map(l => l.variant).join(",")));
        if (options.length > 0) lines.push(i3 + "options " + Kdl.quote(options.join(",")));
        lines.push(i2 + "}");
        if (repeatDelay !== 600) lines.push(i2 + "repeat-delay " + repeatDelay);
        if (repeatRate !== 25) lines.push(i2 + "repeat-rate " + repeatRate);
        if (trackLayout === "window") lines.push(i2 + "track-layout \"window\"");
        if (numlock) lines.push(i2 + "numlock");
        lines.push(i1 + "}");
        return lines.join("\n");
    }

    function rendered(text)
    {
        const input = Kdl.findBlock(text, "input", 0);
        if (!input) return text.replace(/\s*$/, "") + "\n\ninput {\n" + renderBlock("    ") + "\n}\n";

        const keyboard = Kdl.findBlock(text, "keyboard", input.open, input.close);
        if (keyboard) return text.substring(0, keyboard.start) + renderBlock(keyboard.indent) + text.substring(keyboard.close + 1);

        return text.substring(0, input.open + 1) + "\n" + renderBlock(input.indent + "    ") + text.substring(input.open + 1);
    }

    function write()
    {
        if (writer.busy) { flush.restart(); return; }
        writer.run([helper, "write", "01-input.kdl", rendered(store.loadedText).replace(/\s*$/, "")]);
    }

    CommandProcess
    {
        id: writer
        onCompleted: code =>
        {
            if (code !== 0) serviceKeyboard.error = writer.errorMessage(Tr.tr("service.keyboard.couldNotSaveTheKeyboardSettings"));
            store.reload();
        }
    }

    function parse(text)
    {
        const input = Kdl.findBlock(text, "input", 0);
        const keyboard = input ? Kdl.findBlock(text, "keyboard", input.open, input.close) : null;
        const block = keyboard ? text.substring(keyboard.open, keyboard.close) : "";
        const value = key => { const m = new RegExp("^\\s*" + key + "\\s+\"([^\"]*)\"", "m").exec(block); return m ? m[1] : null };
        const number = (key, fallback) => { const m = new RegExp("^\\s*" + key + "\\s+(\\d+)", "m").exec(block); return m ? parseInt(m[1], 10) : fallback };

        const codes = (value("layout") || "us").split(",").map(s => s.trim());
        const vars = (value("variant") || "").split(",").map(s => s.trim());
        layouts = codes.filter(c => c !== "").map((c, i) => ({ layout: c, variant: vars[i] || "" }));

        const options = (value("options") || "").split(",").map(s => s.trim()).filter(o => o !== "");
        switchOption = options.find(o => o.startsWith("grp:")) || "";
        capsOption = options.find(o => o.startsWith("caps:") || o === "ctrl:nocaps" || o === "ctrl:swapcaps") || "";
        otherOptions = options.filter(o => o !== switchOption && o !== capsOption);

        repeatDelay = number("repeat-delay", 600);
        repeatRate = number("repeat-rate", 25);
        trackLayout = value("track-layout") === "window" ? "window" : "global";
        numlock = /^\s*numlock\s*$/m.test(block);
        loaded = true;
    }

    FileView
    {
        id: store

        property string loadedText: ""

        path: serviceKeyboard.file
        printErrors: false

        watchChanges: true
        onFileChanged: reload()
        onLoaded: { loadedText = text(); serviceKeyboard.parse(loadedText) }
        onLoadFailed: { loadedText = ""; serviceKeyboard.parse("") }
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
