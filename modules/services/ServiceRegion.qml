pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: serviceRegion

    property string timezone: ""
    property bool   ntp: false
    property bool   canNtp: true
    property string locale: ""

    readonly property var calendarLocale:
    {
        const candidates = [Quickshell.env("LC_ALL"), Quickshell.env("LC_TIME"), Quickshell.env("LANG"), locale];
        for (const candidate of candidates)
        {
            const name = String(candidate || "").split(/[.@]/)[0];
            // C/POSIX has no region, so continue to the next regional locale.
            if (!name || ["C", "POSIX"].includes(name.toUpperCase())) continue;
            const region = Qt.locale(name);
            if (region.name !== "C") return region;
        }
        return Qt.locale();
    }
    property var timezoneCountries: ({})
    property var timezoneAliases: ({})
    property var weekStarts: ({})
    readonly property string zoneinfoDirectory: Quickshell.env("TZDIR") || "/usr/share/zoneinfo"
    readonly property string timezoneCountry:
    {
        let zone = timezone;
        const visited = new Set();
        while (!timezoneCountries[zone] && timezoneAliases[zone] && !visited.has(zone))
        {
            visited.add(zone);
            zone = timezoneAliases[zone];
        }
        return timezoneCountries[zone] || "";
    }
    readonly property int firstDayOfWeek: timezoneCountry && weekStarts["001"] !== undefined
        ? (weekStarts[timezoneCountry] ?? weekStarts["001"]) : calendarLocale.firstDayOfWeek % 7

    FileView
    {
        path: serviceRegion.zoneinfoDirectory + "/zone.tab"
        blockLoading: true
        printErrors: false
        onLoaded:
        {
            const countries = {};
            for (const line of text().split("\n"))
            {
                if (line.startsWith("#")) continue;
                const fields = line.split("\t");
                if (fields.length >= 3) countries[fields[2]] = fields[0].split(",")[0];
            }
            serviceRegion.timezoneCountries = countries;
        }
    }
    FileView
    {
        path: serviceRegion.zoneinfoDirectory + "/tzdata.zi"
        blockLoading: true
        printErrors: false
        onLoaded:
        {
            const aliases = {};
            for (const line of text().split("\n"))
            {
                const link = /^(?:L|Link)\s+(\S+)\s+(\S+)/.exec(line);
                if (link) aliases[link[2]] = link[1];
            }
            serviceRegion.timezoneAliases = aliases;
        }
    }
    FileView
    {
        path: Paths.shellDir + "/assets/calendar/week-start.json"
        blockLoading: true
        onLoaded: serviceRegion.weekStarts = JSON.parse(text()).firstDay
    }

    property var timezones: []
    property var locales: []

    readonly property bool busy: changer.busy
    property string error: ""
    property string notice: ""

    function refresh()
    {
        refreshCalendar();
        if (timezones.length === 0) zoneLister.running = true;
        if (locales.length === 0) localeLister.running = true;
    }

    function refreshCalendar() { timeReader.running = true; localeReader.running = true; }

    function run(command, after)
    {
        if (busy) return;
        error = "";
        changer.after = after || "";
        changer.run(command);
    }

    function setTimezone(zone) { if (zone && zone !== timezone) run(["timedatectl", "set-timezone", zone]) }
    function setNtp(on) { if (on !== ntp) run(["timedatectl", "set-ntp", on ? "true" : "false"]) }
    function setLocale(lang) { if (lang && lang !== locale) run(["localectl", "set-locale", "LANG=" + lang], "relogin") }

    CommandProcess
    {
        id: changer

        property string after: ""

        onCompleted: code =>
        {
            if (code === 0)
            {
                if (after === "relogin") serviceRegion.notice = Tr.tr("service.region.signInAgain");
            }
            else
            {
                const message = changer.errorText;

                serviceRegion.error = /not authorized|authentication|interactive/i.test(message) ? Tr.tr("service.region.authorizationRequired") : (message || Tr.tr("service.region.applyFailed"));
            }
            serviceRegion.refresh();
        }
    }

    Process
    {
        id: timeReader
        command: ["timedatectl", "show", "-p", "Timezone", "-p", "NTP", "-p", "CanNTP"]
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                for (const line of text.split("\n"))
                {
                    const [key, value] = [line.substring(0, line.indexOf("=")), line.substring(line.indexOf("=") + 1)];
                    if (key === "Timezone") serviceRegion.timezone = value;
                    else if (key === "NTP") serviceRegion.ntp = value === "yes";
                    else if (key === "CanNTP") serviceRegion.canNtp = value === "yes";
                }
            }
        }
    }

    Process
    {
        id: localeReader
        command: ["localectl", "status"]
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const m = /LANG=([^\s]+)/.exec(text);
                serviceRegion.locale = m ? m[1] : "";
            }
        }
    }

    Process
    {
        id: zoneLister
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { onStreamFinished: serviceRegion.timezones = text.split("\n").filter(z => z !== "") }
    }

    Process
    {
        id: localeLister
        command: ["localectl", "list-locales"]
        stdout: StdioCollector { onStreamFinished: serviceRegion.locales = text.split("\n").filter(l => l !== "") }
    }
}
