.pragma library

function matchBrace(text, open) {
    let depth = 0;
    for (let i = open; i < text.length; i++) {
        const c = text[i];
        if (c === "\"") { for (i++; i < text.length && text[i] !== "\""; i++) if (text[i] === "\\") i++; }
        else if (c === "/" && text[i + 1] === "/") { const nl = text.indexOf("\n", i); i = nl < 0 ? text.length : nl; }
        else if (c === "/" && text[i + 1] === "*") { const end = text.indexOf("*/", i + 2); i = end < 0 ? text.length : end + 1; }
        else if (c === "{") depth++;
        else if (c === "}" && --depth === 0) return i;
    }
    return -1;
}

function lineAt(text, start) {
    const nl = text.indexOf("\n", start);
    return text.substring(start, nl < 0 ? text.length : nl);
}
function isComment(line) { return /^\s*\/\//.test(line) }

function findBlocks(text, name, from, to) {
    const end = to === undefined ? text.length : to;
    const re = new RegExp("(^|\\n)([ \\t]*)" + name + "(?=[\\s{])[^\\n{]*\\{", "g");
    re.lastIndex = from || 0;
    const out = [];
    let m;
    while ((m = re.exec(text)) !== null) {
        const start = m.index + m[1].length;
        if (start >= end) break;
        if (isComment(lineAt(text, start))) continue;
        const open = text.indexOf("{", start);
        const close = matchBrace(text, open);
        if (close < 0) break;
        out.push({ start: start, open: open, close: close, indent: m[2] });
        re.lastIndex = close;
    }
    return out;
}
function findBlock(text, name, from, to) { const all = findBlocks(text, name, from, to); return all.length > 0 ? all[0] : null }

function topLines(text, block) {
    const out = [];
    let depth = 0, lineStart = block.open + 1, lineDepth = 0;
    for (let i = block.open + 1; i < block.close; i++) {
        const c = text[i];
        if (c === "\"") { for (i++; i < block.close && text[i] !== "\""; i++) if (text[i] === "\\") i++; continue; }
        if (c === "/" && text[i + 1] === "/") { const nl = text.indexOf("\n", i); i = (nl < 0 || nl > block.close ? block.close : nl) - 1; continue; }
        if (c === "{") depth++;
        else if (c === "}") depth--;
        else if (c === "\n") {
            if (lineDepth === 0) out.push({ start: lineStart, end: i, text: text.substring(lineStart, i) });
            lineStart = i + 1;
            lineDepth = depth;
        }
    }
    if (lineDepth === 0 && lineStart < block.close) out.push({ start: lineStart, end: block.close, text: text.substring(lineStart, block.close) });
    return out;
}

function node(text, block, name) {
    const re = new RegExp("^\\s*" + name + "(\\s|$|;)");
    return topLines(text, block).find(l => !isComment(l.text) && re.test(l.text)) || null;
}

function value(text, block, name) {
    const l = node(text, block, name);
    if (!l) return null;
    const m = new RegExp("^\\s*" + name + "\\s+(\"([^\"]*)\"|[^\\s;]+)").exec(l.text);
    return m ? (m[2] !== undefined ? m[2] : m[1]) : "";
}

function setNode(text, block, name, line) {
    const l = node(text, block, name);
    const indent = block.indent + "    ";
    if (l) return text.substring(0, l.start) + indent + line + text.substring(l.end);
    return text.substring(0, block.open + 1) + "\n" + indent + line + text.substring(block.open + 1);
}

function removeNode(text, block, name) {
    const l = node(text, block, name);
    if (!l) return text;
    return text.substring(0, l.start) + text.substring(Math.min(text.length, l.end + 1));
}

function quote(s) { return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"" }
