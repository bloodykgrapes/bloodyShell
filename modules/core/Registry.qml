pragma Singleton

import QtQuick
import Quickshell

Singleton
{
    id: registry

    readonly property var edgeOptions: [
        {label: Tr.tr("common.top"), value: Enums.EdgeTop}, {label: Tr.tr("common.bottom"), value: Enums.EdgeBottom},
        {label: Tr.tr("common.left"), value: Enums.EdgeLeft}, {label: Tr.tr("common.right"), value: Enums.EdgeRight}
    ]
    readonly property var panelStyleOptions: [
        {label: Tr.tr("common.disabled"), value: Enums.PanelDisabled}, {label: Tr.tr("settings.frame.outFrame"), value: Enums.OutFrame},
        {label: Tr.tr("settings.frame.inFrame"), value: Enums.InFrame}
    ]
    readonly property var barStyleOptions: [
        {label: Tr.tr("settings.structure.center"), value: Enums.BarCenter},
        {label: Tr.tr("common.left"), value: Enums.BarLeft},
        {label: Tr.tr("common.right"), value: Enums.BarRight},
        {label: Tr.tr("settings.structure.full"), value: Enums.BarFull},
        {label: Tr.tr("settings.appearance.equalizerWaves"), value: Enums.BarWaves}
    ]

    function usesStatusBubbles(style)
    {
        return style === Enums.BarCenter || style === Enums.BarLeft || style === Enums.BarRight;
    }
    readonly property var equalizerOptions: [
        {label: Tr.tr("settings.appearance.equalizerBars"), value: Enums.EqualizerBars},
        {label: Tr.tr("settings.appearance.equalizerWaves"), value: Enums.EqualizerWaves}
    ]
    readonly property var themeOptions: [
        {label: Tr.tr("settings.appearance.autoTheme"), value: Enums.ThemeAuto},
        {label: Tr.tr("settings.appearance.dark"), value: Enums.ThemeDark},
        {label: Tr.tr("settings.appearance.light"), value: Enums.ThemeLight},
        {label: Tr.tr("settings.appearance.wallpaperTheme"), value: Enums.ThemeWallpaper}
    ]
    readonly property var accentModeOptions: [
        {label: Tr.tr("settings.appearance.accentAuto"), value: Enums.AccentAuto},
        {label: Tr.tr("settings.appearance.accentCustom"), value: Enums.AccentCustom}
    ]
    readonly property var highlightOptions: [
        {label: Tr.tr("settings.appearance.highlightRed"), value: Enums.HighlightRed},
        {label: Tr.tr("settings.appearance.highlightOrange"), value: Enums.HighlightOrange},
        {label: Tr.tr("settings.appearance.highlightYellow"), value: Enums.HighlightYellow},
        {label: Tr.tr("settings.appearance.highlightAccent"), value: Enums.HighlightAccent},
        {label: Tr.tr("settings.appearance.highlightCustom"), value: Enums.HighlightCustom}
    ]
    readonly property var motionStyleOptions: [
        {label: Tr.tr("settings.appearance.motionDirect"), value: Enums.MotionDirect},
        {label: Tr.tr("settings.appearance.motionFluid"), value: Enums.MotionFluid},
        {label: Tr.tr("settings.appearance.motionGlide"), value: Enums.MotionGlide}
    ]
    readonly property var wallpaperPauseOptions: [
        {label: Tr.tr("common.never"), value: Enums.PauseNever},
        {label: Tr.tr("settings.appearance.pauseFullscreen"), value: Enums.PauseFullscreen},
        {label: Tr.tr("settings.appearance.pauseCovered"), value: Enums.PauseCovered}
    ]
    readonly property var scrollActionOptions: [
        {label: Tr.tr("common.off"), value: 0},
        {label: Tr.tr("common.volume"), value: 1},
        {label: Tr.tr("settings.island.brightness"), value: 2}
    ]
    readonly property var launcherStyleOptions: [
        {label: Tr.tr("common.floating"), value: Enums.LauncherFloating},
        {label: Tr.tr("settings.appearance.launcherIsland"), value: Enums.LauncherIsland}
    ]
    readonly property var windowBorderOptions: [
        {label: Tr.tr("common.off"), value: Enums.BorderOff},
        {label: Tr.tr("settings.windows.borderFocused"), value: Enums.BorderFocused},
        {label: Tr.tr("settings.windows.borderAll"), value: Enums.BorderAll}
    ]
    readonly property var windowColorOptions: [
        {label: Tr.tr("settings.windows.colorAccent"), value: Enums.ColorAccent},
        {label: Tr.tr("settings.windows.colorGray"), value: Enums.ColorGray},
        {label: Tr.tr("settings.windows.colorWhite"), value: Enums.ColorWhite}
    ]
    readonly property var windowAnimationOptions: [
        {label: Tr.tr("settings.windows.animationNiri"), value: Enums.WindowNiri},
        {label: Tr.tr("settings.windows.animationBouncy"), value: Enums.WindowBouncy},
        {label: Tr.tr("settings.windows.animationInstant"), value: Enums.WindowInstant}
    ]
    readonly property var surfaceOptions: [
        {label: Tr.tr("settings.appearance.surfaceSolid"), value: Enums.SurfaceSolid},
        {label: Tr.tr("settings.appearance.surfaceBackdrop"), value: Enums.SurfaceBackdrop},
        {label: Tr.tr("settings.appearance.surfaceBlur"), value: Enums.SurfaceBlur}
    ]
    readonly property var layoutShortcutOptions: [
        {label: Tr.tr("settings.timeLanguage.superSpace"), value: "grp:win_space_toggle"},
        {label: Tr.tr("settings.timeLanguage.altShift"), value: "grp:alt_shift_toggle"},
        {label: Tr.tr("settings.timeLanguage.ctrlShift"), value: "grp:ctrl_shift_toggle"},
        {label: Tr.tr("settings.timeLanguage.altSpace"), value: "grp:alt_space_toggle"},
        {label: Tr.tr("settings.timeLanguage.ctrlSpace"), value: "grp:ctrl_space_toggle"},
        {label: Tr.tr("settings.timeLanguage.capsLock"), value: "grp:caps_toggle"},
        {label: Tr.tr("settings.timeLanguage.bothShifts"), value: "grp:shifts_toggle"},
        {label: Tr.tr("settings.timeLanguage.rightAlt"), value: "grp:toggle"},
        {label: Tr.tr("common.none"), value: ""}
    ]

    readonly property var windows:
    [
        "launcher",
        "power",
        "settings",
        "wallpapers",
        "helper"
    ]
    readonly property var overlaySources:
    ({
        launcher: Qt.resolvedUrl("../ui/overlay/launcher/Launcher.qml"),
        power: Qt.resolvedUrl("../ui/overlay/power/Power.qml"),
        settings: Qt.resolvedUrl("../ui/overlay/settings/Settings.qml"),
        wallpapers: Qt.resolvedUrl("../ui/overlay/wallpapers/Wallpapers.qml"),
        helper: Qt.resolvedUrl("../ui/overlay/helper/Helper.qml"),
        desktopMenu: Qt.resolvedUrl("../ui/desktop/DesktopMenu.qml")
    })

    readonly property url statusWidget: Qt.resolvedUrl("../ui/bar/widgets/WidgetStatus.qml")
    readonly property var widgets:
    ({
        island:       { title: Tr.tr("shell.dynamicIsland"),    url: Qt.resolvedUrl("../ui/bar/widgets/WidgetIsland.qml"),     collapse: false },
        clock:         { title: Tr.tr("shell.clock"),           url: Qt.resolvedUrl("../ui/bar/widgets/WidgetClock.qml"),         collapse: false, menu: Qt.resolvedUrl("../ui/bar/menus/MenuClock.qml") },
        status:        { title: Tr.tr("shell.status"),          url: statusWidget, collapse: false },
        statusConnections: { url: statusWidget, variant: "connections", collapse: false },
        statusSystem:      { url: statusWidget, variant: "system", collapse: false },
        keyboard:      { url: statusWidget, variant: "keyboard", collapse: false },
        volume:        { url: statusWidget, variant: "volume", collapse: false },
        network:       { url: statusWidget, variant: "network", collapse: false },
        bluetooth:     { url: statusWidget, variant: "bluetooth", collapse: false },
        media:         { title: Tr.tr("settings.island.media"), url: Qt.resolvedUrl("../ui/bar/widgets/WidgetMedia.qml"), collapse: false, menu: Qt.resolvedUrl("../ui/bar/menus/MenuMedia.qml") },
        tray:          { title: Tr.tr("shell.tray"),            url: Qt.resolvedUrl("../ui/bar/widgets/WidgetTray.qml"),          collapse: false, menu: Qt.resolvedUrl("../ui/bar/menus/MenuTray.qml") },
        update:        { title: Tr.tr("shell.updateAvailable"), url: Qt.resolvedUrl("../ui/bar/widgets/WidgetUpdate.qml"),        collapse: false, hidden: true },
        window:        { title: Tr.tr("common.windowTitle"),    url: Qt.resolvedUrl("../ui/bar/widgets/WidgetWindow.qml"),        collapse: true,  vertical: true },
        workspaces:    { title: Tr.tr("shell.workspaces"),      url: Qt.resolvedUrl("../ui/bar/widgets/WidgetWorkspaces.qml"),    collapse: false },
    })

    readonly property var settingsGroups: [Tr.tr("common.general"), Tr.tr("common.system"), Tr.tr("common.shell"), Tr.tr("shell.other")]
    readonly property var settings:
    [
        { id: "home",          group: 0, title: Tr.tr("settings.structure.home"),       icon: Icon.settingsHome,         page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageHome.qml") },
        { id: "appearance",    group: 0, title: Tr.tr("common.appearance"),             icon: Icon.settingsAppearance,   page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageAppearance.qml") },
        { id: "wallpaper",     group: 0, title: Tr.tr("settings.appearance.wallpaper"),  icon: Icon.wallpapers,           page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageWallpaper.qml") },

        { id: "display",       group: 1, title: Tr.tr("settings.structure.displays"),    icon: Icon.settingsDisplay,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageDisplay.qml") },
        { id: "sound",         group: 1, title: Tr.tr("common.sound"),                   icon: Icon.settingsSound,        page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageSound.qml") },
        { id: "power",         group: 1, title: Tr.tr("common.power"),                   icon: Icon.settingsPower,        page: Qt.resolvedUrl("../ui/overlay/settings/pages/PagePower.qml") },
        { id: "timeLanguage",  group: 1, title: Tr.tr("settings.structure.region"),      icon: Icon.settingsTimeLanguage, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageTimeLanguage.qml") },
        { id: "storage",       group: 1, title: Tr.tr("common.storage"),                 icon: Icon.settingsStorage,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageStorage.qml") },
        { id: "devices",       group: 1, title: Tr.tr("settings.devices.title"),         icon: Icon.settingsDevices,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageDevices.qml") },
        { id: "applications",  group: 1, title: Tr.tr("common.applications"),            icon: Icon.settingsApplications, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageApplications.qml") },
        { id: "user",          group: 1, title: Tr.tr("common.user"),                    icon: Icon.user,                 page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageUser.qml") },

        { id: "surfaces",      group: 2, title: Tr.tr("settings.structure.surfaces"),    icon: Icon.settingsSurfaces,     page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageSurfaces.qml") },
        { id: "bar",           group: 2, title: Tr.tr("common.bar"),                     icon: Icon.settingsBar,          page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageBar.qml") },
        { id: "dock",          group: 2, title: Tr.tr("common.dock"),                    icon: Icon.settingsDock,         page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageDock.qml") },
        { id: "desktop",       group: 2, title: Tr.tr("common.desktop"),                 icon: Icon.settingsDesktop,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageDesktop.qml") },
        { id: "windows",       group: 2, title: Tr.tr("settings.structure.windows"),     icon: Icon.settingsWindows,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageWindows.qml") },
        { id: "components",    group: 2, title: Tr.tr("settings.components.title"),       icon: Icon.widgets,              page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageComponents.qml") },
        { id: "shortcuts",     group: 2, title: Tr.tr("settings.structure.shortcuts"),   icon: Icon.shortcuts,            page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageShortcuts.qml") },

        { id: "capture",       group: 2, hidden: true, parent: "components", title: Tr.tr("settings.structure.screenCapture"), icon: Icon.screenshot, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageCapture.qml") },
        { id: "onScreenKeyboard", group: 2, hidden: true, parent: "components", title: Tr.tr("keyboard.title"), icon: Icon.keyboard, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageOnScreenKeyboard.qml") },
        { id: "launcher",      group: 2, hidden: true, parent: "components", title: Tr.tr("common.launcher"), icon: Icon.search, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageLauncher.qml") },
        { id: "lock",          group: 2, hidden: true, parent: "components", title: Tr.tr("common.lockScreen"), icon: Icon.userLock, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageLock.qml") },
        { id: "login",         group: 2, hidden: true, parent: "components", title: Tr.tr("settings.imports.greeter"), icon: Icon.loginScreen, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageLogin.qml") },
        { id: "easyEffects",   group: 2, hidden: true, parent: "components", title: "Easy Effects", icon: Icon.audioEffects, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageEasyEffects.qml") },
        { id: "plymouth",      group: 2, hidden: true, parent: "components", title: "Plymouth", icon: Icon.plymouth, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PagePlymouth.qml") },

        { id: "updates",       group: 3, title: Tr.tr("common.updates"),             icon: Icon.settingsUpdates,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageUpdates.qml") },
        { id: "hub",           group: 3, title: Tr.tr("settings.structure.hub"),    icon: Icon.packages,             page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageHub.qml") },
        { id: "about",         group: 3, title: Tr.tr("common.about"),               icon: Icon.settingsAbout,        page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageAbout.qml") },

        { id: "fileAssociations", group: 1, hidden: true, parent: "applications", title: Tr.tr("settings.fileAssociations.title"), icon: Icon.fileAssociations, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageFileAssociations.qml") },
        { id: "allApplications", group: 1, hidden: true, parent: "applications", title: Tr.tr("settings.applications.all"), icon: Icon.settingsApplications, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageAllApplications.qml") },
    ]

    readonly property var settingsPages: settings.filter(page => page.hidden !== true)

    function settingsIndex(id) { return settings.findIndex(page => page.id === id) }
    function settingsTabIndex(index)
    {
        const page = settings[index];
        if (!page) return 0;
        const id = page.parent || page.id;
        return Math.max(0, settingsPages.findIndex(entry => entry.id === id));
    }
    function settingsParent(index)
    {
        const page = settings[index];
        return page && page.parent ? settings.find(entry => entry.id === page.parent) || null : null;
    }
}
