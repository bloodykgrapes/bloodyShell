pragma Singleton

import QtQuick
import Quickshell

Singleton
{
    id: registry

    readonly property var windows:
    [
        "launcher",
        "power",
        "settings",
        "wallpapers",
        "helper"
    ]
    readonly property var widgets:
    ({
        clock:         { title: Tr.tr("shell.clock"),           url: Qt.resolvedUrl("../bar/widgets/WidgetClock.qml"),         collapse: false, menu: Qt.resolvedUrl("../bar/menus/MenuClock.qml") },
        media:         { title: Tr.tr("shell.media"),           url: Qt.resolvedUrl("../bar/widgets/WidgetMedia.qml"),         collapse: true,  menu: Qt.resolvedUrl("../bar/menus/MenuMedia.qml") },
        notifications: { title: Tr.tr("common.notifications"),  url: Qt.resolvedUrl("../bar/widgets/WidgetNotifications.qml"), collapse: false, menu: Qt.resolvedUrl("../bar/menus/MenuNotifications.qml") },
        status:        { title: Tr.tr("shell.status"),          url: Qt.resolvedUrl("../bar/widgets/WidgetStatus.qml"),        collapse: false },
        tray:          { title: Tr.tr("shell.tray"),            url: Qt.resolvedUrl("../bar/widgets/WidgetTray.qml"),          collapse: false, menu: Qt.resolvedUrl("../bar/menus/MenuTray.qml") },
        system:          { title: Tr.tr("common.system"),            url: Qt.resolvedUrl("../bar/widgets/WidgetSystem.qml"),          collapse: false, menu: Qt.resolvedUrl("../bar/menus/MenuSystem.qml") },
        user:          { title: Tr.tr("common.system"),            url: Qt.resolvedUrl("../bar/widgets/WidgetSystem.qml"),          collapse: false, hidden: true, menu: Qt.resolvedUrl("../bar/menus/MenuSystem.qml") },
        update:        { title: Tr.tr("shell.updateAvailable"), url: Qt.resolvedUrl("../bar/widgets/WidgetUpdate.qml"),        collapse: false, hidden: true },
        window:        { title: Tr.tr("common.windowTitle"),    url: Qt.resolvedUrl("../bar/widgets/WidgetWindow.qml"),        collapse: true,  vertical: false },
        workspaces:    { title: Tr.tr("shell.workspaces"),      url: Qt.resolvedUrl("../bar/widgets/WidgetWorkspaces.qml"),    collapse: false },
    })

    readonly property var settingsGroups: ["", Tr.tr("common.system"), Tr.tr("common.shell"), Tr.tr("shell.other")]
    readonly property var settings:
    [
        { id: "general",       group: 0, title: Tr.tr("common.general"),            icon: Icon.settingsGeneral,      page: Qt.resolvedUrl("../overlay/settings/pages/PageGeneral.qml") },

        { id: "display",       group: 1, title: Tr.tr("common.display"),            icon: Icon.settingsDisplay,      page: Qt.resolvedUrl("../overlay/settings/pages/PageDisplay.qml") },
        { id: "sound",         group: 1, title: Tr.tr("common.sound"),              icon: Icon.settingsSound,        page: Qt.resolvedUrl("../overlay/settings/pages/PageSound.qml") },
        { id: "networks",      group: 1, title: Tr.tr("menu.network.networks"),     icon: Icon.networkWiFiON,         page: Qt.resolvedUrl("../overlay/settings/pages/PageNetworks.qml") },
        { id: "power",         group: 1, title: Tr.tr("common.power"),              icon: Icon.settingsPower,        page: Qt.resolvedUrl("../overlay/settings/pages/PagePower.qml") },
        { id: "storage",       group: 1, title: Tr.tr("common.storage"),            icon: Icon.settingsStorage,      page: Qt.resolvedUrl("../overlay/settings/pages/PageStorage.qml") },
        { id: "devices",       group: 1, title: Tr.tr("menu.bluetooth.devices"),    icon: Icon.settingsDevices,      page: Qt.resolvedUrl("../overlay/settings/pages/PageDevices.qml") },
        { id: "applications",  group: 1, title: Tr.tr("common.applications"),       icon: Icon.settingsApplications, page: Qt.resolvedUrl("../overlay/settings/pages/PageApplications.qml") },
        { id: "timeLanguage",  group: 1, title: Tr.tr("common.timeLanguage"),       icon: Icon.settingsTimeLanguage, page: Qt.resolvedUrl("../overlay/settings/pages/PageTimeLanguage.qml") },
        { id: "user",          group: 1, title: Tr.tr("common.user"),               icon: Icon.user,                 page: Qt.resolvedUrl("../overlay/settings/pages/PageUser.qml") },

        { id: "appearance",    group: 2, title: Tr.tr("common.appearance"),         icon: Icon.settingsAppearance,   page: Qt.resolvedUrl("../overlay/settings/pages/PageAppearance.qml") },
        { id: "desktop",       group: 2, title: Tr.tr("common.desktop"),            icon: Icon.settingsDesktop,      page: Qt.resolvedUrl("../overlay/settings/pages/PageDesktop.qml") },
        { id: "bar",           group: 2, title: Tr.tr("common.bar"),                icon: Icon.settingsBar,          page: Qt.resolvedUrl("../overlay/settings/pages/PageBar.qml") },
        { id: "dock",          group: 2, title: Tr.tr("common.dock"),               icon: Icon.settingsDock,         page: Qt.resolvedUrl("../overlay/settings/pages/PageDock.qml") },
        { id: "launcher",      group: 2, title: Tr.tr("common.launcher"),           icon: Icon.settingsLauncher,     page: Qt.resolvedUrl("../overlay/settings/pages/PageLauncher.qml") },
        { id: "osd",           group: 2, title: Tr.tr("shell.osd"),                 icon: Icon.settingsOSD,          page: Qt.resolvedUrl("../overlay/settings/pages/PageOSD.qml") },
        { id: "lockScreen",    group: 2, title: Tr.tr("common.lockScreen"),         icon: Icon.settingsLock,         page: Qt.resolvedUrl("../overlay/settings/pages/PageLock.qml") },
        { id: "compositor",    group: 2, title: Tr.tr("settings.about.compositor"), icon: Icon.settingsCompositor,   page: Qt.resolvedUrl("../overlay/settings/pages/PageCompositor.qml") },

        { id: "updates",       group: 3, title: Tr.tr("common.updates"),            icon: Icon.settingsUpdates,      page: Qt.resolvedUrl("../overlay/settings/pages/PageUpdates.qml") },
        { id: "about",         group: 3, title: Tr.tr("common.about"),              icon: Icon.settingsAbout,        page: Qt.resolvedUrl("../overlay/settings/pages/PageAbout.qml") },
    ]
}
