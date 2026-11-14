.pragma library
.import "../src/Kdl.js" as Kdl

function number(v) { return String(Math.round(v * 1000) / 1000) }

function outputs(all)
{
    const lines = [];
    for (const name of Object.keys(all).sort())
    {
        const d = all[name];
        lines.push("", "output " + Kdl.quote(name) + " {");
        if (d.enabled === false) lines.push("    off");
        else
        {
            if (d.mode) lines.push("    mode " + Kdl.quote(d.mode));
            lines.push("    scale " + number(d.scale || 1));
            lines.push("    transform " + Kdl.quote(d.transform || "normal"));
            if (d.position) lines.push("    position x=" + Math.round(d.position.x) + " y=" + Math.round(d.position.y));
            if (d.vrr === "on") lines.push("    variable-refresh-rate");
            else if (d.vrr === "on-demand") lines.push("    variable-refresh-rate on-demand=true");
        }
        lines.push("}");
    }
    return lines.join("\n");
}

function keyboard(settings, indent)
{
    const {layouts, switchOption, capsOption, otherOptions, repeatDelay, repeatRate, trackLayout, numlock} = settings;
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

function keyboardSettings(text)
{
    text = Kdl.nodeLines(text);
    const input = Kdl.findBlock(text, "input", 0);
    const keyboard = input ? Kdl.findBlock(text, "keyboard", input.open, input.close) : null;
    const block = keyboard ? text.substring(keyboard.open, keyboard.close) : "";
    const xkb = keyboard ? Kdl.findBlock(text, "xkb", keyboard.open, keyboard.close) : null;
    const xkbBlock = xkb ? text.substring(xkb.open, xkb.close) : "";
    const value = (key, source = block) =>
    {
        const m = new RegExp('^\\s*' + key + '\\s+("(?:\\\\.|[^"\\\\])*")', "m").exec(source);
        return m ? JSON.parse(m[1]) : null;
    };
    const number = (key, fallback) => { const m = new RegExp("^\\s*" + key + "\\s+(\\d+)", "m").exec(block); return m ? parseInt(m[1], 10) : fallback };

    const codes = (value("layout", xkbBlock) || "us").split(",").map(s => s.trim());
    const vars = (value("variant", xkbBlock) || "").split(",").map(s => s.trim());
    const layouts = codes.filter(c => c !== "").map((c, i) => ({ layout: c, variant: vars[i] || "" }));

    const options = (value("options", xkbBlock) || "").split(",").map(s => s.trim()).filter(o => o !== "");
    const switchOption = options.find(o => o.startsWith("grp:")) || "";
    const capsOption = options.find(o => o.startsWith("caps:") || o === "ctrl:nocaps" || o === "ctrl:swapcaps") || "";
    const otherOptions = options.filter(o => o !== switchOption && o !== capsOption);

    const repeatDelay = number("repeat-delay", 600);
    const repeatRate = number("repeat-rate", 25);
    const trackLayout = value("track-layout") === "window" ? "window" : "global";
    const numlock = /^\s*numlock\s*$/m.test(block);
    return {layouts, switchOption, capsOption, otherOptions, repeatDelay, repeatRate, trackLayout, numlock};
}

