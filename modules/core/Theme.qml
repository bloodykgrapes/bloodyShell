pragma Singleton

import QtQuick
import Quickshell

import "../services"

Singleton
{
    id: theme

    readonly property string fontText: "sans-serif"
    readonly property string fontMono: "JetBrains Mono"

    readonly property var neutralStyles:
    [
        ["#eeeef2", "#e3e3e9", "#fafafd"],
        ["#101012", "#08080a", "#1c1c1e"]
    ]
    function tinted(base: color, saturation: real): color
    {
        if (!accentShell || accentBase.hslSaturation < 0.03) return base;
        return Qt.hsla(Math.max(0, accentBase.hslHue), Math.min(saturation, accentBase.hslSaturation * 0.6), base.a < 1 ? Math.max(0.08, Math.min(0.92, base.hslLightness)) : base.hslLightness, base.a);
    }

    readonly property var styles: neutralStyles.map(palette => palette.map(color => tinted(color, 0.24)))
    readonly property var  style: styles[light ? Enums.ThemeLight : Enums.ThemeDark]
    readonly property bool light: Config.themeStyle === Enums.ThemeLight

    readonly property real ink: light ? 0 : 1
    function inkAlpha(a) { return Qt.rgba(text1.r, text1.g, text1.b, a) }

    readonly property color colorSolid: style[0]
    readonly property color colorLine:  tinted(light ? "#ababB5" : "#47474a", 0.16)

    readonly property color text1: tinted(light ? "#1d1d1f" : "#f5f5f7", 0.10)
    readonly property color text2: tinted(light ? "#34343a" : "#aeaeb2", 0.10)
    readonly property color text3: tinted(light ? "#414147" : "#9a9a9a", 0.10)
    readonly property color text4: inkAlpha(0.5)

    readonly property bool  accentShell: Config.themeAccent
    readonly property color accentBase:  ServiceAppearance.accent
    readonly property color accent:      Qt.hsla(Math.max(0, accentBase.hslHue), Math.min(0.7, accentBase.hslSaturation), light ? 0.36 : 0.72, 1)
    function accentAlpha(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }
    function tone(a) { return accentShell ? accentAlpha(a * (light ? 1.3 : 1.6)) : inkAlpha(a) }

    readonly property color colorHover:       tone(0.07)
    readonly property color colorHoverStrong: tone(0.2)
    readonly property color colorPressed:     tone(0.14)
    readonly property color colorRaised: tinted(light ? "#ffffff" : "#343438", 0.18)
    readonly property color colorHairline: inkAlpha(light ? 0.10 : 0.09)

    readonly property color colorField:       inkAlpha(0.07)
    readonly property color colorAccent:      accentShell ? accent : text1
    readonly property color colorSelection:   accentShell ? accentAlpha(0.3) : inkAlpha(light ? 0.14 : 0.22)
    readonly property color colorChosen:      accentShell ? accentAlpha(0.3) : (light ? "#e2e2e6" : colorLine)
    readonly property color colorCurrent:     accentShell ? accentAlpha(0.16) : inkAlpha(0.07)

    function lightForeground(background: color): bool
    {
        const c = [background.r, background.g, background.b].map(v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
        return c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722 < 0.179;
    }
    readonly property color onAccent: lightForeground(colorAccent) ? "#ffffff" : "#000000"
    readonly property color onCritical: lightForeground(colorCritical) ? "#ffffff" : "#000000"

    readonly property color colorWarning:   light ? "#805000" : "#ffb340"
    readonly property color colorCritical:  light ? "#b42332" : "#ff6b6b"
    readonly property color colorAttention: light ? "#874500" : "#ff9f0a"

    readonly property int borderWidth: Config.themeBorder ? 1 : 0

    readonly property color frameColor: tinted(light ? "#f5f5f7" : accentShell ? "#08080a" : "#000000", 0.24)
    readonly property int frameThickness: Math.max(0, Math.min(8, Config.frameThickness))
    readonly property int frameRadius: 24
    readonly property int frameSmoothing: 24
    readonly property int sidebarWidth: 380
    readonly property int sidebarCorner: 28

    readonly property int radiusSmall:  8
    readonly property int radiusMedium: 10
    readonly property int radiusLarge:  16

    readonly property real barThickness:     44
    readonly property real barVerticalWidth: 38
    readonly property int  barPadding:       10
    readonly property int  barMargin:        10
    readonly property int  barRadius:        22
    readonly property int  barSpacing:       10
    readonly property int  barReveal:        4
    readonly property int  barHideDelay:     450

    readonly property int barWidgetHeight:  24
    readonly property int barWidgetPadding: 2
    readonly property int barWidgetRadius:  barWidgetHeight / 2

    readonly property int barGroupThickness:  barWidgetHeight + 4
    readonly property int barGroupRadius:     barGroupThickness / 2

    readonly property int titleMaxWidth: 200

    readonly property int   menuWidth:      280
    readonly property int   menuPadding:    10
    readonly property color menuColorHover: colorHover

    readonly property int dockPadding:       10
    readonly property int dockMargin:        12
    readonly property int dockRadius:        26
    readonly property int dockSpacing:       8
    readonly property int dockReveal:        20
    readonly property int dockSeparatorSize: 9
    readonly property int dockHideDelay:     300

    readonly property int launcherWidth:   660
    readonly property int launcherSearch:  54
    readonly property int launcherRow:     52
    readonly property int launcherPadding: 18
    readonly property int launcherRadius:  24
    readonly property int launcherSpacing: 8

    readonly property int settingsWidth:   1080
    readonly property int settingsHeight:  720
    readonly property int settingsSidebar: 232
    readonly property int settingsRadius:  24

    readonly property color settingsColorBackground: colorSolid
    readonly property color settingsColorSidebar:    style[1]
    readonly property color settingsColorCard:       style[2]
    readonly property color settingsColorLine:       inkAlpha(0.06)

    readonly property color lockSurface: colorSolid
    readonly property color lockSurfaceEdge: inkAlpha(0.12)
    readonly property color lockHover:     accentShell ? Qt.rgba(accentBase.r, accentBase.g, accentBase.b, 0.32) : inkAlpha(0.16)
    readonly property color lockPressed:   accentShell ? Qt.rgba(accentBase.r, accentBase.g, accentBase.b, 0.45) : inkAlpha(0.26)
    readonly property color lockStrong:    inkAlpha(0.14)
    readonly property color lockFocus:     accentShell ? Qt.rgba(accentBase.r, accentBase.g, accentBase.b, 0.12) : inkAlpha(0.06)
    readonly property color lockHighlight: accentShell ? accent : text1
    readonly property color lockSelection: accentShell ? Qt.rgba(accentBase.r, accentBase.g, accentBase.b, 0.45) : inkAlpha(0.3)
    readonly property color lockText1:     text1
    readonly property color lockText2:     text2
    readonly property color lockText3:     text3

    readonly property int animationDurationBar:     Config.animationsFluid ? 360 : 220
    readonly property int animationDurationDock:    Config.animationsFluid ? 360 : 220
    readonly property int animationDurationMorph:   Config.animationsFluid ? 420 : 240
    readonly property int animationDurationOpen:    Config.animationsFluid ? 460 : 220
    readonly property int animationDurationClose:   Config.animationsFluid ? 190 : 140
    readonly property int animationDurationControl: Config.animationsFluid ? 320 : 160

    readonly property var easingEmphasized: Config.animationsFluid ? [0.16, 0.85, 0.2, 1.0, 1.0, 1.0] : [0.2, 0.0, 0.2, 1.0, 1.0, 1.0]
    readonly property var easingAccelerate: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
}
