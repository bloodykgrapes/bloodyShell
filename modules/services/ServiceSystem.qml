pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../core"

Singleton
{
    id: serviceSystem

    property var release: ({})
    readonly property string distribution: release.ID || "linux"
    readonly property string logo: ServiceAppearance.iconPath(release.LOGO || distribution + "-logo")
        || ServiceAppearance.iconPath("distributor-logo") || Icon.settingsGeneral

    FileView
    {
        path: "/etc/os-release"
        printErrors: false
        onLoaded:
        {
            const values = {};
            for (const line of text().split("\n"))
            {
                const match = line.match(/^([A-Z_]+)=(.*)$/);
                if (!match) continue;
                values[match[1]] = match[2].trim().replace(/^["']|["']$/g, "");
            }
            serviceSystem.release = values;
        }
    }
}
