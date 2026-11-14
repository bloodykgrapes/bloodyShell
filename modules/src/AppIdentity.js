.pragma library

function appKey(w) { return w.app_id ? w.app_id : "id:" + w.id; }

function matchKey(value)
{
    return String(value).toLowerCase().replace(/\.desktop$/, "").split(".").pop();
}

function sameApp(a, b) { return matchKey(a) === matchKey(b); }

function trayIdentityTokens(value)
{
    const text = String(value || "")
        .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
        .replace(/\.desktop$/i, "")
        .toLocaleLowerCase();

    const ignored = [
        "org", "com", "net", "io", "app", "apps", "desktop",
        "application", "client", "instance", "status", "notifier",
        "system", "tray", "item", "indicator", "helper", "service",
        "launcher", "shell", "kde", "gnome", "qt", "electron"
    ];

    return text.split(/[^a-z0-9]+/).filter(token =>
        token.length >= 3 && !ignored.includes(token)
    );
}

function trayIdentityScore(left, right)
{
    const a = String(left || "").trim()
        .toLocaleLowerCase().replace(/\.desktop$/i, "");
    const b = String(right || "").trim()
        .toLocaleLowerCase().replace(/\.desktop$/i, "");

    if (!a || !b) return 0;
    if (a === b) return 100;

    const aEnd = a.split(/[.\/\s_-]+/).filter(Boolean).pop() || "";
    const bEnd = b.split(/[.\/\s_-]+/).filter(Boolean).pop() || "";

    if (aEnd.length >= 4 && aEnd === bEnd) return 85;

    const aTokens = trayIdentityTokens(a);
    const bTokens = trayIdentityTokens(b);

    let shared = 0;

    for (const token of aTokens)
        if (bTokens.includes(token)) shared++;

    return shared > 0 ? 50 + Math.min(20, shared * 5) : 0;
}

function mediaAppVariants(value)
{
    const raw = String(value || "")
        .trim()
        .toLowerCase()
        .replace(/\.desktop$/, "");

    const result = [];

    function add(value)
    {
        const token = String(value || "")
            .toLowerCase()
            .replace(/\.desktop$/, "")
            .replace(/[^a-z0-9]/g, "");

        if (token.length >= 3 && !result.includes(token))
            result.push(token);
    }

    if (!raw)
        return result;

    add(raw);
    add(raw.split("/").pop());

    const dbusApp = raw
        .replace(/^org\.mpris\.mediaplayer2\./, "")
        .replace(/\.instance.*$/, "");

    add(dbusApp);

    const ignored = [
        "org",
        "com",
        "net",
        "mpris",
        "mediaplayer2",
        "instance"
    ];

    for (const part of raw.split(/[./]/))
    {
        if (part.length >= 3 && !ignored.includes(part))
            add(part);
    }

    return result;
}
