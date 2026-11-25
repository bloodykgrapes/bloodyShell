.pragma library
.import "../src/Kdl.js" as Kdl

function number(v) { return String(Math.round(v * 1000) / 1000) }

function hasOverviewBackdrop(config, layerRules)
{
    const source = Kdl.nodeLines(config).replace(/^[ \t]*include[ \t]+"(?:\.\/)?bloodyShell\/03-layer\.kdl"[ \t]*$/m,
        () => Kdl.nodeLines(layerRules));
    let enabled = false;
    for (const rule of Kdl.findBlocks(source, "layer-rule", 0))
    {
        const body = source.substring(rule.open + 1, rule.close);
        if (!/^[ \t]*match[ \t]+namespace="\^bloodyShell:overview-backdrop\$"[ \t]*$/m.test(body)) continue;
        const placement = /^[ \t]*place-within-backdrop[ \t]+(true|false)[ \t]*$/m.exec(body);
        if (placement) enabled = placement[1] === "true";
    }
    return enabled;
}

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
    lines.push(i3 + "variant " + Kdl.quote(layouts.some(l => l.variant !== "") ? layouts.map(l => l.variant).join(",") : ""));
    lines.push(i3 + "options " + Kdl.quote(options.join(",")));
    lines.push(i2 + "}");
    lines.push(i2 + "repeat-delay " + repeatDelay, i2 + "repeat-rate " + repeatRate);
    lines.push(i2 + "track-layout " + Kdl.quote(trackLayout));
    lines.push(i2 + (numlock ? "numlock" : "numlock false"));
    lines.push(i1 + "}");
    return lines.join("\n");
}

function keyboardSettings(text, defaults = "")
{
    const blocks = source =>
    {
        source = Kdl.nodeLines(source);
        const input = Kdl.findBlock(source, "input", 0);
        const keyboard = input ? Kdl.findBlock(source, "keyboard", input.open, input.close) : null;
        const xkb = keyboard ? Kdl.findBlock(source, "xkb", keyboard.open, keyboard.close) : null;
        return {
            keyboard: keyboard ? source.substring(keyboard.open, keyboard.close) : "",
            xkb: xkb ? source.substring(xkb.open, xkb.close) : ""
        };
    };
    const primary = blocks(text), fallback = blocks(defaults);
    const match = (pattern, section) => pattern.exec(primary[section]) ?? pattern.exec(fallback[section]);
    const value = (key, section = "keyboard") =>
    {
        const m = match(new RegExp('^\\s*' + key + '\\s+("(?:\\\\.|[^"\\\\])*")', "m"), section);
        return m ? JSON.parse(m[1]) : null;
    };
    const number = (key, defaultValue) => {
        const m = match(new RegExp("^\\s*" + key + "\\s+(\\d+)", "m"), "keyboard");
        return m ? parseInt(m[1], 10) : defaultValue;
    };

    const codes = (value("layout", "xkb") || "us").split(",").map(s => s.trim());
    const vars = (value("variant", "xkb") || "").split(",").map(s => s.trim());
    const layouts = codes.filter(c => c !== "").map((c, i) => ({ layout: c, variant: vars[i] || "" }));

    const options = (value("options", "xkb") || "").split(",").map(s => s.trim()).filter(o => o !== "");
    const switchOption = options.find(o => o.startsWith("grp:")) || "";
    const capsOption = options.find(o => o.startsWith("caps:") || o === "ctrl:nocaps" || o === "ctrl:swapcaps") || "";
    const otherOptions = options.filter(o => o !== switchOption && o !== capsOption);

    const repeatDelay = number("repeat-delay", 600);
    const repeatRate = number("repeat-rate", 25);
    const trackLayout = value("track-layout") === "window" ? "window" : "global";
    const numlockFlag = match(/^[ \t]*numlock(?:[ \t]+(true|false))?[ \t]*$/m, "keyboard");
    const numlock = numlockFlag !== null && numlockFlag[1] !== "false";
    return {layouts, switchOption, capsOption, otherOptions, repeatDelay, repeatRate, trackLayout, numlock};
}

