.pragma library

const weekStarts = Object.create(null);

function countries(text) {
    const result = Object.create(null);
    for (const line of text.split("\n")) {
        if (!line || line.startsWith("#")) continue;
        const fields = line.split("\t");
        if (fields.length >= 3) result[fields[2]] = fields[0].split(",")[0];
    }
    return result;
}

function aliases(text) {
    const result = Object.create(null);
    for (const line of text.split("\n")) {
        const link = /^(?:L|Link)\s+(\S+)\s+(\S+)/.exec(line);
        if (link) result[link[2]] = link[1];
    }
    return result;
}

function country(zone, countries, aliases) {
    const visited = new Set();
    while (!countries[zone] && aliases[zone] && !visited.has(zone)) {
        visited.add(zone);
        zone = aliases[zone];
    }
    return countries[zone] || "";
}

function firstDay(country, fallback) {
    if (!country) return fallback;
    if (weekStarts[country] !== undefined) return weekStarts[country];
    // QML cannot enumerate QLocale territories. Find a supported language for
    // this country; an unsupported pair silently falls back to another country.
    for (let index = 0; index < 26 * 26; index++) {
        const language = String.fromCharCode(97 + Math.floor(index / 26), 97 + index % 26);
        const locale = Qt.locale(language + "_" + country);
        if (locale.name.split("_")[1] === country) {
            weekStarts[country] = locale.firstDayOfWeek % 7;
            return weekStarts[country];
        }
    }
    // Qt's neutral locale uses the ISO week when a territory is unavailable.
    weekStarts[country] = Qt.locale("C").firstDayOfWeek % 7;
    return weekStarts[country];
}
