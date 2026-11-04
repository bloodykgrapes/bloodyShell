pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Всё общее экрана входа: настройки вида, цвета, значки и кнопки питания.
//
// Настройки кладёт шелл (ServiceGreeter) в /var/lib/bloodyShell/settings.json; нет файла — вид по умолчанию.
// Цвета: элементы сплошные (без прозрачности), средне-серые — заметны и на тёмных обоях, и на светлых (обои
// ещё и затемнены), а тень (Widgets.Shadow) отделяет их от любого фона. Наведение и нажатие — заметно
// светлее. Акцент (если в шелле включён Accent shell) красит фокус поля, кнопку входа, выделение и наведение.
Singleton
{
    id: root

    // ---------- настройки ----------
    readonly property string dir: Quickshell.env("BLOODYSHELL_CONFIG") || "/var/lib/bloodyShell"

    property int animationLevel: 1
    readonly property bool animationsEnabled: animationLevel >= 1
    readonly property bool animationsFluid: animationLevel >= 2
    property bool accentShell: false
    property string accentColor: "#8ecbff"
    property string wallpaperCurrent: ""
    property bool widgetClock24: true

    FileView
    {
        path: root.dir + "/settings.json"
        printErrors: false
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded:
        {
            let s;
            try { s = JSON.parse(text()) } catch (e) { console.warn("[Theme] settings.json:", e); return }
            for (const key of ["animationLevel", "accentShell", "accentColor", "wallpaperCurrent", "widgetClock24"])
                if (s[key] !== undefined && typeof s[key] === typeof root[key]) root[key] = s[key];
        }
    }

    // ---------- цвета ----------
    readonly property string fontText: "Noto Sans"

    readonly property color text1: "#ffffff"
    readonly property color text2: "#c9c9c9"

    readonly property color surface: "#3a3a41"         // аватар и кнопки
    readonly property color surfaceStrong: "#4a4a52"   // кнопка входа
    readonly property color colorLine: "#5c5c65"       // рамка поля и аватара

    readonly property color accent: accentColor
    // с акцентом наведение и нажатие подкрашены им (смешано с поверхностью — остаётся сплошным)
    function tone(base, amount) { return accentShell ? Qt.tint(base, Qt.rgba(accent.r, accent.g, accent.b, amount)) : base }

    readonly property color colorHover: tone("#5a5a64", 0.3)
    readonly property color colorPressed: tone("#6c6c77", 0.35)
    readonly property color colorField: "#2c2c32"
    readonly property color colorFieldFocus: tone("#34343b", 0.18)
    readonly property color colorAccent: accentShell ? accent : text1
    readonly property color colorSelection: accentShell ? Qt.tint("#3a3a40", Qt.rgba(accent.r, accent.g, accent.b, 0.5)) : "#4a4a50"
    readonly property color colorCritical: "#ff6b6b"

    readonly property var easingEmphasized: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var easingAccelerate: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]

    // ---------- значки: icons/<имя>.svg, все светлые — экран всегда на тёмных обоях ----------
    function icon(name) { return Qt.resolvedUrl("icons/" + name + ".svg") }

    // ---------- питание: suspend | reboot | poweroff ----------
    function power(action)
    {
        if (!powerProcess.running) powerProcess.exec(["systemctl", action]);
    }
    Process { id: powerProcess }
}
