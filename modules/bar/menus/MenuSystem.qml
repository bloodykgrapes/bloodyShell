pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

import "../../components"
import "../../components/bar"
import "../../core"
import "../../services"

Menu
{
    id: menuSystem

    implicitWidth: 280

    readonly property string user: ServiceUser.user
    readonly property string fullName: ServiceUser.fullName

    Timer { interval: 30000; running: true; repeat: true; onTriggered: uptimeFile.reload() }

    readonly property string uptime:
    {
        const s = parseFloat(String(uptimeFile.text()).split(" ")[0]) || 0;
        if (s <= 0) return "";
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        if (d > 0) return (h > 0 ? Tr.tr("menu.user.upDH") : Tr.tr("menu.user.upD")).arg(d).arg(h);
        if (h > 0) return Tr.tr("menu.user.upHMin").arg(h).arg(m);
        return Tr.tr("menu.user.upMin").arg(Math.max(1, m));
    }

    FileView { id: uptimeFile; path: "/proc/uptime"; printErrors: false }

    readonly property string avatar: ServiceUser.avatar

    Item
    {
        width: parent.width
        height: 64

        ClippingRectangle
        {
            id: avatar

            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
            width: 46
            height: 46
            radius: 23
            color: Theme.colorField

            scale: Config.animationsFluid ? 0.6 : 1
            Component.onCompleted: scale = 1
            Spring on scale {}

            ShellIcon
            {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                icon: Icon.user
                size: 22
            }
            Image
            {
                id: face
                anchors.fill: parent
                source: menuSystem.avatar !== "" ? "file://" + menuSystem.avatar : ""
                sourceSize: Qt.size(96, 96)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                opacity: status === Image.Ready ? 1 : 0
                Smooth on opacity { duration: 220 }
            }
        }

        Column
        {
            anchors { left: avatar.right; leftMargin: 12; right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 1

            ShellText
            {
                width: parent.width
                label: Tr.tr("common.system")
                size: 11
                color: Theme.text3
            }
            ShellText
            {
                width: parent.width
                label: menuSystem.fullName !== "" ? menuSystem.fullName : menuSystem.user
                size: 15
                color: Theme.text1
                font.weight: Font.DemiBold
            }
            ShellText
            {
                width: parent.width
                label: [menuSystem.fullName !== "" && menuSystem.fullName !== menuSystem.user ? "@" + menuSystem.user : "", menuSystem.uptime].filter(s => s !== "").join("  ·  ")
                size: 10
                color: Theme.text4
            }
        }
    }

    MenuSeparator { }

    MenuItem { icon: Icon.search;     text: Tr.tr("common.launcher");     onClicked: { MenuState.close(); OverlayState.show("launcher")   } }
    MenuItem { icon: Icon.wallpapers; text: Tr.tr("menu.user.wallpapers"); onClicked: { MenuState.close(); OverlayState.show("wallpapers") } }
    MenuItem { icon: Icon.settings;   text: Tr.tr("common.settings");   onClicked: { MenuState.close(); OverlayState.show("settings")   } }

    MenuSeparator { }

    MenuItem { icon: Icon.reload; text: Tr.tr("menu.user.reloadShell"); onClicked: { Quickshell.reload(true) } }
    MenuItem { icon: Icon.computerPowerOff; text: Tr.tr("common.power"); onClicked: { MenuState.close(); OverlayState.show("power") } }
}
