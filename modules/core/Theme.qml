pragma Singleton

import QtQuick
import Quickshell

import "../services"

Singleton
{
    id: theme

    readonly property string fontText: "sans-serif"
    readonly property string fontMono: "JetBrains Mono"
    readonly property string fontBrand: comfortaa.status === FontLoader.Ready ? comfortaa.name : fontText

    FontLoader { id: comfortaa; source: Qt.resolvedUrl("../../assets/fonts/comfortaa/Comfortaa.ttf") }

    readonly property var neutralStyles:
    [
        ["#f0f0f4", "#e6e6ec", "#fcfcfe"],
        ["#141416", "#101012", "#212124"]
    ]
    function tinted(base: color, saturation: real): color
    {
        // Accent is a single control color. It must never tint the neutral shell palette.
        return base;
    }

    readonly property bool light: Config.themeStyle === Enums.ThemeLight
        || (Config.themeStyle === Enums.ThemeAuto || Config.themeStyle === Enums.ThemeWallpaper)
            && ServiceAppearance.effectiveThemeStyle === Enums.ThemeLight
    readonly property bool wallpaperColors: Config.themeStyle === Enums.ThemeWallpaper
        && ServiceColors.wallpaperThemeReady
    function paletteColorFor(lightMode, role, fallback)
    {
        return ServiceColors.paletteFor(lightMode)?.[role] || fallback;
    }
    function paletteColor(role, fallback) { return paletteColorFor(light, role, fallback); }
    function wallpaperStyleFor(lightMode)
    {
        return [
            paletteColorFor(lightMode, "surface", lightMode ? "#f0f0f4" : "#141416"),
            paletteColorFor(lightMode, "surface_container_low", lightMode ? "#e6e6ec" : "#101012"),
            paletteColorFor(lightMode, "surface_container", lightMode ? "#fcfcfe" : "#212124")
        ];
    }
    readonly property var wallpaperStyles: [wallpaperStyleFor(true), wallpaperStyleFor(false)]
    readonly property var styles: wallpaperColors ? wallpaperStyles : neutralStyles
    readonly property var style: styles[light ? Enums.ThemeLight : Enums.ThemeDark]

    function inkAlpha(a) { return Qt.rgba(text1.r, text1.g, text1.b, a) }

    readonly property color colorSolid: style[0]
    readonly property color colorLine: wallpaperColors ? paletteColor("outline_variant", light ? "#ababB5" : "#47474a")
        : tinted(light ? "#ababB5" : "#47474a", 0.16)

    function textFor(lightMode) { return tinted(lightMode ? "#1d1d1f" : "#f5f5f7", 0.10); }
    readonly property bool frostedText: Config.shellSurface === Enums.SurfaceBlur && ShellMaterial.blur
    readonly property color text1: wallpaperColors ? paletteColor("on_surface", textFor(light)) : textFor(light)
    readonly property color text2: wallpaperColors ? paletteColor("on_surface_variant", textFor(light))
        : tinted(frostedText ? (light ? "#232329" : "#ececf0") : (light ? "#34343a" : "#aeaeb2"), 0.10)
    readonly property color text3: wallpaperColors ? paletteColor("on_surface_variant", textFor(light))
        : tinted(frostedText ? (light ? "#2c2c32" : "#dcdce1") : (light ? "#414147" : "#9a9a9a"), 0.10)
    readonly property color text4: inkAlpha(0.5)

    function hue(value) { return (((Number(value) || 0) % 360) + 360) % 360 / 360; }

    readonly property bool accentAutomatic: Config.themeAccentMode !== Enums.AccentCustom
    readonly property bool accentShell: true
    readonly property color accentBase: Config.themeAccentMode === Enums.AccentCustom
        ? Qt.hsla(hue(Config.accentHue), 0.68, light ? 0.46 : 0.64, 1)
        : ServiceColors.sourceColor || "#8ecbff"
    function accentFor(lightMode) { return Qt.hsla(Math.max(0, accentBase.hslHue), Math.min(0.7, accentBase.hslSaturation), lightMode ? 0.36 : 0.72, 1); }
    readonly property color accent: accentFor(light)
    function accentAlpha(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }
    function tone(a) { return accentShell ? accentAlpha(a * (light ? 1.3 : 1.6)) : inkAlpha(a) }

    readonly property color highlightBase:
    {
        if (Config.highlightStyle === Enums.HighlightRed) return Qt.hsla(hue(2), 0.76, light ? 0.43 : 0.64, 1);
        if (Config.highlightStyle === Enums.HighlightYellow) return Qt.hsla(hue(47), 0.88, light ? 0.42 : 0.64, 1);
        if (Config.highlightStyle === Enums.HighlightAccent) return accent;
        if (Config.highlightStyle === Enums.HighlightCustom) return Qt.hsla(hue(Config.highlightHue), 0.78, light ? 0.44 : 0.65, 1);
        return Qt.hsla(hue(27), 0.84, light ? 0.45 : 0.64, 1);
    }
    readonly property color highlight: highlightBase
    function highlightAlpha(a) { return Qt.rgba(highlight.r, highlight.g, highlight.b, a) }

    readonly property color colorHover:       tone(0.07)
    readonly property color colorHoverStrong: tone(0.2)
    readonly property color colorPressed:     tone(0.14)
    readonly property color colorRaised: wallpaperColors ? paletteColor("surface_container_high", style[2])
        : tinted(light ? "#ffffff" : "#343438", 0.18)
    readonly property color colorHairline: inkAlpha(light ? 0.10 : 0.09)
    readonly property int panelBorderWidth: 1
    readonly property color colorPanelEdge: inkAlpha(light ? 0.14 : 0.16)
    readonly property color colorShadow: Qt.rgba(0, 0, 0, light ? 0.18 : 0.42)
    readonly property color colorFocus: highlightAlpha(0.7)

    readonly property color colorField:       inkAlpha(0.07)
    readonly property color colorAccent:      accentShell ? accent : text1
    readonly property color colorSelection:   accentShell ? accentAlpha(0.3) : inkAlpha(light ? 0.14 : 0.22)
    readonly property color colorFieldFocus:  Qt.tint(colorField, colorSelection)
    readonly property color colorChosen:      accentShell ? accentAlpha(0.3) : (light ? "#e2e2e6" : colorLine)
    readonly property color colorCurrent:     accentShell ? accentAlpha(0.16) : inkAlpha(0.07)

    function luminance(color: color): real
    {
        const channels = [color.r, color.g, color.b].map(v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
    }
    function lightForeground(background: color): bool { return luminance(background) < 0.179; }
    readonly property color accentForeground: lightForeground(colorAccent) ? "#ffffff" : "#000000"
    readonly property color onCritical: lightForeground(colorCritical) ? "#ffffff" : "#000000"

    readonly property color colorWarning:   highlightBase
    readonly property color colorCritical: light ? "#b42332" : "#ff6b6b"
    function criticalAlpha(a) { return Qt.rgba(colorCritical.r, colorCritical.g, colorCritical.b, a) }
    readonly property color colorAttention: highlightBase

    function frameFor(lightMode) { return wallpaperColors ? paletteColorFor(lightMode, "surface_dim", lightMode ? "#f5f5f7" : "#000000")
        : tinted(lightMode ? "#f5f5f7" : "#000000", 0.24); }
    readonly property color frameColor: frameFor(light)
    readonly property int frameThickness: Math.max(0, Math.min(8, Config.frameThickness))
    readonly property int frameRadius: Math.max(0, Math.min(30, Config.frameRadius))
    readonly property int menuRadius: Config.menuRadius
    readonly property int panelGap: 10
    readonly property int controlRadius: 14
    readonly property color controlColorBackground: popupColorCard
    readonly property color controlColorBorder: inkAlpha(light ? 0.12 : 0.10)
    readonly property color controlColorActive: Qt.tint(controlColorBackground, accentShell ? accentAlpha(0.20) : inkAlpha(0.13))

    readonly property int radiusSmall:  8
    readonly property int radiusMedium: 10
    readonly property int radiusLarge:  16

    readonly property real barThickness:     44
    readonly property real barVerticalWidth: 38
    readonly property int  barPadding:       10
    readonly property int  barRadius:        22
    readonly property int  dockRadius:       22
    readonly property color panelButtonBackground: Qt.tint(frameColor, colorField)
    readonly property int  barSpacing:       10
    readonly property int  barReveal:        4
    readonly property int  barHideDelay:     450

    readonly property int barWidgetHeight:  24
    readonly property int barStandaloneWidgetHeight: barWidgetHeight + 6
    readonly property int barBubbleSize:   36
    readonly property int barBubbleIconSize: 17
    readonly property int barWidgetPadding: 2
    readonly property int barWidgetRadius:  barWidgetHeight / 2
    readonly property int workspaceDotSize: 7
    readonly property int workspaceActiveLength: 24
    readonly property int workspaceDotPadding: 3

    readonly property int barGroupThickness:  barBubbleSize

    readonly property int titleMaxWidth: 200

    readonly property int   menuWidth:      280
    readonly property int   menuPadding:    10
    readonly property color menuColorHover: colorHover
    readonly property int menuControlRadius: 18
    readonly property color menuControlBackground: Qt.tint(frameColor, colorField)
    readonly property color menuControlSelected: colorSelection
    readonly property color popupColorBackground: light ? colorSolid : style[1]
    readonly property color popupColorCard: style[2]
    readonly property color popupColorSelected: Qt.tint(popupColorCard, accentShell ? accentAlpha(0.16) : inkAlpha(0.12))
    readonly property int popupPadding: 20
    readonly property int popupTitleSize: 17
    readonly property int popupRadius: 22

    readonly property int dockPadding:       10
    readonly property int dockSpacing:       8
    readonly property int dockReveal:        20
    readonly property int dockSeparatorSize: 9
    readonly property int dockHideDelay:     300

    readonly property int launcherWidth:   660
    readonly property int launcherSearch:  52
    readonly property int launcherRow:     56
    readonly property int launcherPadding: 12
    readonly property int launcherRadius:  24
    readonly property int launcherSpacing: 8

    readonly property int settingsWidth:   1280
    readonly property int settingsHeight:  860
    readonly property int settingsSidebar: 212
    readonly property int settingsRadius:  24
    readonly property int controlHeight: 38
    readonly property int settingsRowHeight: 64
    readonly property int settingsRowInset: 20
    readonly property int settingsRowGap: 22
    readonly property int settingsSectionGap: 24
    readonly property int settingsTabHeight: 38
    readonly property int settingsLabelSize: 13
    readonly property int controlTextSize: 12

    function controlWidth(item, preferred)
    {
        for (let parent = item.parent; parent; parent = parent.parent)
            if (parent.controlAvailableWidth !== undefined) return Math.min(preferred, parent.controlAvailableWidth);
        return preferred;
    }

    readonly property color settingsColorBackground: popupColorBackground
    readonly property color settingsColorSidebar: Qt.tint(light ? style[2] : colorSolid, inkAlpha(light ? 0.025 : 0.035))
    readonly property color settingsColorCard:       popupColorCard
    readonly property color settingsColorLine:      inkAlpha(light ? 0.09 : 0.075)
    readonly property color settingsColorHover: light
        ? Qt.tint(Qt.tint(settingsColorCard, inkAlpha(0.14)), accentShell ? accentAlpha(0.04) : "transparent")
        : Qt.tint(settingsColorCard, colorHover)
    readonly property color settingsColorPressed: light
        ? Qt.tint(Qt.tint(settingsColorCard, inkAlpha(0.20)), accentShell ? accentAlpha(0.04) : "transparent")
        : Qt.tint(settingsColorCard, colorPressed)

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

    readonly property real motionSpeed: Math.max(0.25, Math.min(2, Number(Config.motionSpeed) || 1))
    function animationDuration(base) { return Config.animationsEnabled ? Math.max(1, Math.round(base / motionSpeed)) : 0 }
    readonly property int animationDurationBar:     animationDuration(Config.motionStyle === Enums.MotionGlide ? 380 : Config.animationsFluid ? 300 : 220)
    readonly property int animationDurationDock:    animationDuration(Config.motionStyle === Enums.MotionGlide ? 380 : Config.animationsFluid ? 300 : 220)
    readonly property int animationDurationMorph:   animationDuration(Config.motionStyle === Enums.MotionGlide ? 460 : Config.animationsFluid ? 340 : 240)
    readonly property int animationDurationOpen:    animationDuration(Config.motionStyle === Enums.MotionGlide ? 500 : Config.animationsFluid ? 340 : 220)
    readonly property int animationDurationClose:   animationDuration(Config.motionStyle === Enums.MotionGlide ? 230 : Config.animationsFluid ? 180 : 140)
    readonly property int animationDurationControl: animationDuration(Config.motionStyle === Enums.MotionGlide ? 340 : Config.animationsFluid ? 240 : 160)

    readonly property var easingEmphasized: Config.motionStyle === Enums.MotionGlide
        ? [0.16, 0.85, 0.2, 1.0, 1.0, 1.0]
        : Config.motionStyle === Enums.MotionFluid
            ? [0.22, 0.61, 0.36, 1.0, 1.0, 1.0]
            : [0.2, 0.0, 0.2, 1.0, 1.0, 1.0]
    readonly property var easingAccelerate: Config.motionStyle === Enums.MotionGlide
        ? [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
        : [0.32, 0.0, 0.67, 1.0, 1.0, 1.0]
}
