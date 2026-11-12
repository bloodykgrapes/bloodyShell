.pragma library

// Expose inline statements as lines without splitting quoted strings or comments.
function nodeLines(text) {
    let out = "", i = 0;
    while (i < text.length) {
        if (text.startsWith("//", i)) {
            const end = text.indexOf("\n", i + 2);
            i = end < 0 ? text.length : end;
        } else if (text.startsWith("/*", i)) {
            let depth = 1;
            i += 2;
            while (i < text.length && depth) {
                if (text.startsWith("/*", i)) { depth++; i += 2; }
                else if (text.startsWith("*/", i)) { depth--; i += 2; }
                else i++;
            }
            out += " ";
        } else {
            const raw = /^(?:r(#+)?|(#+))"/.exec(text.substring(i));
            const opening = raw ? i + raw[0].length - 1 : i;
            const triple = text.startsWith('"""', opening);
            if (raw || triple) {
                const quote = triple ? '"""' : '"', hashes = raw ? raw[1] || raw[2] || "" : "";
                const start = opening + quote.length, end = text.indexOf(quote + hashes, start);
                out += JSON.stringify(text.substring(start, end < 0 ? text.length : end));
                i = end < 0 ? text.length : end + quote.length + hashes.length;
            } else if (text[i] === '"') {
                const start = i++;
                while (i < text.length) {
                    if (text[i] === "\\") i += 2;
                    else if (text[i++] === '"') break;
                }
                out += text.substring(start, i);
            } else {
                const c = text[i++];
                out += c === ";" ? "\n" : c === "{" || c === "}" ? c + "\n" : c;
            }
        }
    }
    return out;
}

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
        const prefix = text.substring(from ? from + 1 : 0, start).replace(/"(?:\\.|[^"\\])*"/g, "");
        if ((prefix.match(/\{/g) || []).length !== (prefix.match(/\}/g) || []).length) continue;
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

function quote(s) { return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"" }
