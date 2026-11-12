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
    readonly property var frameOptions: [
        {label: Tr.tr("settings.frame.inFrame"), value: Enums.InFrame}, {label: Tr.tr("settings.frame.outFrame"), value: Enums.OutFrame},
        {label: Tr.tr("settings.frame.filled"), value: Enums.Filled}, {label: Tr.tr("settings.frame.islands"), value: Enums.Islands}
    ]
    readonly property var animationOptions: [
        {label: Tr.tr("settings.appearance.minimal"), value: Enums.AnimationsDisabled},
        {label: Tr.tr("settings.appearance.standard"), value: Enums.AnimationsStandard},
        {label: Tr.tr("settings.appearance.fluid"), value: Enums.AnimationsFluid}
    ]
    readonly property var themeOptions: [
        {label: Tr.tr("settings.appearance.light"), value: Enums.ThemeLight},
        {label: Tr.tr("settings.appearance.dark"), value: Enums.ThemeDark}
    ]
    readonly property var menuOptions: [
        {label: Tr.tr("common.default"), value: Enums.MenuDefault},
        {label: Tr.tr("common.floating"), value: Enums.MenuFloating}
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

    readonly property var widgets:
    ({
        island: { title: Tr.tr("shell.dynamicIsland"), url: Qt.resolvedUrl("../ui/osd/OSDContent.qml"), collapse: false },
        clock:         { title: Tr.tr("shell.clock"),           url: Qt.resolvedUrl("../ui/bar/widgets/WidgetClock.qml"),         collapse: false, menu: Qt.resolvedUrl("../ui/bar/menus/MenuClock.qml") },
        notifications: { title: Tr.tr("common.notifications"),  url: Qt.resolvedUrl("../ui/bar/widgets/WidgetNotifications.qml"), collapse: false, menu: Qt.resolvedUrl("../ui/bar/menus/MenuNotifications.qml") },
        status:        { title: Tr.tr("shell.status"),          url: Qt.resolvedUrl("../ui/bar/widgets/WidgetStatus.qml"),        collapse: false },
        tray:          { title: Tr.tr("shell.tray"),            url: Qt.resolvedUrl("../ui/bar/widgets/WidgetTray.qml"),          collapse: false, menu: Qt.resolvedUrl("../ui/bar/menus/MenuTray.qml") },
        update:        { title: Tr.tr("shell.updateAvailable"), url: Qt.resolvedUrl("../ui/bar/widgets/WidgetUpdate.qml"),        collapse: false, hidden: true },
        window:        { title: Tr.tr("common.windowTitle"),    url: Qt.resolvedUrl("../ui/bar/widgets/WidgetWindow.qml"),        collapse: true,  vertical: true },
        workspaces:    { title: Tr.tr("shell.workspaces"),      url: Qt.resolvedUrl("../ui/bar/widgets/WidgetWorkspaces.qml"),    collapse: false },
    })

    readonly property var settingsGroups: ["", Tr.tr("common.system"), Tr.tr("common.shell"), Tr.tr("shell.other")]
    readonly property var settings:
    [
        { id: "general",       group: 0, title: Tr.tr("common.general"),            icon: Icon.settingsGeneral,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageGeneral.qml") },

        { id: "display",       group: 1, title: Tr.tr("common.display"),            icon: Icon.settingsDisplay,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageDisplay.qml") },
        { id: "sound",         group: 1, title: Tr.tr("common.sound"),              icon: Icon.settingsSound,        page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageSound.qml") },
        { id: "networks",      group: 1, title: Tr.tr("menu.network.networks"),     icon: Icon.networkWiFiON,         page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageNetworks.qml") },
        { id: "power",         group: 1, title: Tr.tr("common.power"),              icon: Icon.settingsPower,        page: Qt.resolvedUrl("../ui/overlay/settings/pages/PagePower.qml") },
        { id: "storage",       group: 1, title: Tr.tr("common.storage"),            icon: Icon.settingsStorage,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageStorage.qml") },
        { id: "devices",       group: 1, title: Tr.tr("menu.bluetooth.devices"),    icon: Icon.settingsDevices,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageDevices.qml") },
        { id: "notifications", group: 1, title: Tr.tr("common.notifications"),      icon: Icon.bellON,               page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageNotifications.qml") },
        { id: "applications",  group: 1, title: Tr.tr("common.applications"),       icon: Icon.settingsApplications, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageApplications.qml") },
        { id: "timeLanguage",  group: 1, title: Tr.tr("common.timeLanguage"),       icon: Icon.settingsTimeLanguage, page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageTimeLanguage.qml") },
        { id: "user",          group: 1, title: Tr.tr("common.user"),               icon: Icon.user,                 page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageUser.qml") },

        { id: "appearance",    group: 2, title: Tr.tr("common.appearance"),         icon: Icon.settingsAppearance,   page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageAppearance.qml") },
        { id: "desktop",       group: 2, title: Tr.tr("common.desktop"),            icon: Icon.settingsDesktop,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageDesktop.qml") },
        { id: "bar",           group: 2, title: Tr.tr("common.bar"),                icon: Icon.settingsBar,          page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageBar.qml") },
        { id: "dock",          group: 2, title: Tr.tr("common.dock"),               icon: Icon.settingsDock,         page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageDock.qml") },
        { id: "island",        group: 2, title: Tr.tr("shell.dynamicIsland"),                 icon: Icon.settingsOSD,          page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageIsland.qml") },
        { id: "shortcuts",     group: 2, title: Tr.tr("settings.shortcuts.title"), icon: Icon.keyboard,             page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageShortcuts.qml") },

        { id: "updates",       group: 3, title: Tr.tr("common.updates"),            icon: Icon.settingsUpdates,      page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageUpdates.qml") },
        { id: "about",         group: 3, title: Tr.tr("common.about"),              icon: Icon.settingsAbout,        page: Qt.resolvedUrl("../ui/overlay/settings/pages/PageAbout.qml") },
    ]
}
