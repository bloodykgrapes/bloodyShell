pragma Singleton

import QtQuick

QtObject
{
    property var configuration: typeof config === "undefined" ? ({}) : config
    readonly property string stateDir: String(configuration.stateDir || "/var/lib/bloodyShell")
    property int animationLevel: Number(configuration.animationLevel === undefined ? 1 : configuration.animationLevel)
    readonly property bool animationsEnabled: animationLevel >= 1
    readonly property bool animationsFluid: animationLevel >= 2
    property string wallpaperCurrent: String(configuration.wallpaperCurrent || "")
    readonly property string avatarUser: String(configuration.avatarUser || "")
    property bool widgetClock24: String(configuration.widgetClock24 === undefined ? "true" : configuration.widgetClock24).toLowerCase() === "true"
    property string shellLanguage: String(configuration.shellLanguage || "system")
    readonly property url keyboardSource: Qt.resolvedUrl(String(configuration.keyboardSource || "../../modules/common/keyboard/Keyboard.qml"))
    readonly property var keyboardLayouts:
    {
        try
        {
            const entries = JSON.parse(String(configuration.keyboardLayouts || "[]"));
            if (Array.isArray(entries) && entries.length && entries.every(entry => typeof entry.layout === "string" && entry.layout.length)) return entries;
        }
        catch (error) {}
        return [{layout: "us", variant: ""}];
    }
    readonly property var locale: shellLanguage === "system" ? Qt.locale() : Qt.locale(shellLanguage)

    readonly property string fontText: "sans-serif"
    readonly property color text1: "#f5f5f7"
    readonly property color text2: "#a1a1aa"
    readonly property color surface: "#161618"
    readonly property color surfaceStrong: "#242428"
    readonly property color colorLine: "#3a3a40"
    readonly property color colorHover: "#2c2c32"
    readonly property color colorPressed: "#3a3a42"
    readonly property color colorField: "#101012"
    readonly property color colorFieldFocus: "#1b1b1f"
    readonly property color colorAccent: text1
    readonly property color colorSelection: "#45454d"
    readonly property color colorCritical: "#ff8585"

    readonly property var easingEmphasized: [0.16, 0.85, 0.2, 1.0, 1.0, 1.0]
    readonly property var easingAccelerate: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]

    function icon(name) { return Qt.resolvedUrl("icons/" + name + ".svg") }
}
