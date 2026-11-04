pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../components"
import "../core"

Singleton
{
    id: serviceRegion

    property string timezone: ""
    property bool   ntp: false
    property bool   canNtp: true
    property string locale: ""

    property var timezones: []
    property var locales: []

    readonly property bool busy: changer.busy
    property string error: ""
    property string notice: ""

    function refresh()
    {
        timeReader.running = true;
        localeReader.running = true;
        if (timezones.length === 0) zoneLister.running = true;
        if (locales.length === 0) localeLister.running = true;
    }

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
                if (after === "relogin") serviceRegion.notice = Tr.tr("service.region.appsUseTheNew");
            }
            else
            {
                const message = changer.errorText;

                serviceRegion.error = /not authorized|authentication|interactive/i.test(message) ? Tr.tr("service.region.notChangedAdministratorPassword") : (message || Tr.tr("service.region.couldNotChangeTheSetting"));
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
