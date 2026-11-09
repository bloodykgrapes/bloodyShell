import QtQuick
import Quickshell
import Quickshell.Widgets

import "../../../common"
import "../../../core"
import "../../../services"
import "../components"

Sidebar
{
    id: leftSidebar
    side: "left"

    function open(name, page = "")
    {
        if (page !== "")
        {
            const index = Registry.settings.findIndex(item => item.id === page);
            if (index >= 0) OverlayState.settingsPage = index;
        }
        SidebarState.close();
        OverlayState.show(name);
    }

    component SidebarAction: ActionButton
    {
        width: (parent.width - parent.spacing) / 2
        height: 36
        radius: 14
        iconSize: 15
    }

    SidebarSection
    {
        host: leftSidebar
        order: 0
        ActionButton
        {
            objectName: "sidebarUser"
            width: parent.width
            height: 72
            radius: 22
            hoverScale: Config.animationsFluid ? 1.015 : 1.01
            pressScale: 0.98
            Accessible.name: Tr.tr("common.user") + ": " + (ServiceUser.fullName || ServiceUser.user)
            onClicked: leftSidebar.open("settings", "user")

            Row
            {
                anchors { fill: parent; margins: 12 }
                spacing: 12
                ClippingRectangle
                {
                    id: avatar
                    width: 44; height: 44; radius: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.colorField
                    Image
                    {
                        id: face
                        anchors.fill: parent
                        source: ServiceUser.avatar ? "file://" + ServiceUser.avatar : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(88, 88)
                        asynchronous: true
                        cache: false
                    }
                    ShellIcon { anchors.centerIn: parent; visible: face.status !== Image.Ready; icon: Icon.user; size: 24 }
                }
                Column
                {
                    width: Math.max(0, parent.width - avatar.width - userChevron.width - parent.spacing * 2)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    ShellText { width: parent.width; label: ServiceUser.fullName || ServiceUser.user; textFormat: Text.PlainText; size: 15; font.weight: Font.DemiBold; color: Theme.text1 }
                    ShellText { width: parent.width; label: "@" + ServiceUser.user; textFormat: Text.PlainText; size: 11; color: Theme.text3 }
                }
                ShellIcon { id: userChevron; anchors.verticalCenter: parent.verticalCenter; icon: Icon.chevronRight; size: 14; opacity: 0.6 }
            }
        }
    }
    SidebarSection
    {
        host: leftSidebar
        order: 1
        WallpaperPreview
        {
            objectName: "sidebarWallpaper"
            width: parent.width
            height: implicitHeight
            onClicked: leftSidebar.open("wallpapers")
        }
    }
    SidebarSection
    {
        host: leftSidebar
        order: 2
        Row
        {
            width: parent.width
            spacing: 12
            SidebarAction
            {
                objectName: "sidebarLauncher"
                icon: Icon.search
                text: Tr.tr("common.launcher")
                enabled: Config.launcherEnabled
                onClicked: leftSidebar.open("launcher")
            }
            SidebarAction
            {
                objectName: "sidebarSettings"
                icon: Icon.settings
                text: Tr.tr("common.settings")
                onClicked: leftSidebar.open("settings")
            }
        }
    }
    SidebarSection
    {
        host: leftSidebar
        order: 3
        Row
        {
            width: parent.width
            spacing: 12
            SidebarAction
            {
                objectName: "sidebarReload"
                icon: Icon.reload
                text: Tr.tr("sidebar.reload")
                onClicked: { SidebarState.close(); Quickshell.reload(true); }
            }
            SidebarAction
            {
                objectName: "sidebarPower"
                icon: Icon.computerPowerOff
                text: Tr.tr("common.power")
                danger: true
                onClicked: leftSidebar.open("power")
            }
        }
    }
}
