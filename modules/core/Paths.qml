pragma Singleton

import Quickshell

Singleton
{
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || home + "/.cache"
    readonly property string shellDir: String(Quickshell.shellDir).replace(/\/+$/, "")
    readonly property string command: shellDir + "/scripts/bloodyShell"
    function commandFor(domain, args = []) { return ["python3", command, "internal", domain].concat(args) }
    readonly property string installDir: configHome + "/quickshell/bloodyShell"
    readonly property string settingsDir: configHome + "/bloodyShell"
    readonly property string stateDir: cacheHome + "/bloodyShell"
}
