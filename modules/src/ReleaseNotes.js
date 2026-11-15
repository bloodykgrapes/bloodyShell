.pragma library

function decode(text)
{
    const names = { amp: "&", quot: '"', apos: "'", lt: "<", gt: ">", nbsp: " " };
    return String(text || "").replace(/&(#x[0-9a-f]+|#\d+|amp|quot|apos|lt|gt|nbsp);/gi, (entity, key) => {
        if (key[0] !== "#") return names[key.toLowerCase()];
        const code = key[1].toLowerCase() === "x" ? parseInt(key.slice(2), 16) : parseInt(key.slice(1), 10);
        return code > 0 && code <= 0x10ffff ? String.fromCodePoint(code) : entity;
    });
}

function resolve(source, baseUrl)
{
    const value = decode(source).trim();
    if (/^https?:\/\//i.test(value)) return value;
    if (value.startsWith("//")) return "https:" + value;
    if (!value || /^[a-z][a-z\d+.-]*:/i.test(value)) return "";
    const base = String(baseUrl).match(/^(https?:\/\/[^/]+)(\/[^?#]*)?/i);
    if (!base) return "";
    const path = value.startsWith("/") ? value : (base[2] || "/") + value;
    const parts = [];
    for (const part of path.split("/"))
    {
        if (part === "..") parts.pop();
        else if (part && part !== ".") parts.push(part);
    }
    return base[1] + "/" + parts.join("/");
}

function htmlImages(html, baseUrl)
{
    const images = [];
    const caption = html.replace(/<img\b(?:[^>"']|"[^"]*"|'[^']*')*>/gi, tag => {
        const attributes = {};
        tag.replace(/([a-z][\w:-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/gi, (_, name, quoted, single, bare) => {
            attributes[name.toLowerCase()] = quoted !== undefined ? quoted : single !== undefined ? single : bare;
            return "";
        });
        const source = resolve(attributes.src, baseUrl);
        if (source) images.push({ source: source, alt: decode(attributes.alt) });
        return "";
    }).replace(/<\/?(?:p|sub)\b[^>]*>/gi, "").replace(/^\s*<br\s*\/?>|<br\s*\/?>\s*$/gi, "").trim();
    return { kind: "gallery", images: images, caption: caption };
}

function markdownImages(line, baseUrl)
{
    const images = [];
    const remaining = line.replace(/!\[([^\]]*)\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+"[^"]*")?\s*\)/g, (_, alt, url) => {
        const source = resolve(url.replace(/^<|>$/g, ""), baseUrl);
        if (source) images.push({ source: source, alt: alt });
        return "";
    });
    return images.length > 0 && !remaining.trim() ? { kind: "gallery", images: images, caption: "" } : null;
}

function parse(text, baseUrl)
{
    const blocks = [], lines = String(text || "").split(/\r?\n/);
    let pending = [], fence = "", mergeImages = false;
    function flush()
    {
        const markdown = pending.join("\n").trim();
        if (markdown)
        {
            blocks.push({ kind: "text", text: markdown });
            mergeImages = false;
        }
        pending = [];
    }
    function gallery(block, merge = false)
    {
        flush();
        const previous = blocks[blocks.length - 1];
        if (merge && mergeImages && previous && previous.kind === "gallery")
            previous.images = previous.images.concat(block.images);
        else blocks.push(block);
        mergeImages = merge && !block.caption;
    }
    for (let i = 0; i < lines.length; i++)
    {
        const line = lines[i], marker = line.match(/^\s{0,3}(`{3,}|~{3,})/);
        if (marker)
        {
            if (!fence) fence = marker[1];
            else if (marker[1][0] === fence[0] && marker[1].length >= fence.length) fence = "";
            pending.push(line);
            continue;
        }
        if (fence) { pending.push(line); continue; }
        if (/^\s*<p(?:\s[^>]*)?>/i.test(line))
        {
            let end = i;
            while (end < lines.length && !/<\/p\s*>/i.test(lines[end])) end++;
            const html = lines.slice(i, end + 1).join("\n");
            if (end < lines.length && /<img\b/i.test(html))
            {
                gallery(htmlImages(html, baseUrl));
                i = end;
                continue;
            }
        }
        if (/^\s*<img\b/i.test(line)) { gallery(htmlImages(line, baseUrl), true); continue; }
        const images = markdownImages(line, baseUrl);
        if (images) gallery(images, true);
        else pending.push(line);
    }
    flush();
    return blocks;
}
