pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../common"
import "../../core"
import "../overlay"

OverlayView
{
    id: desktopMenu

    name: "desktopMenu"
    readonly property bool open: active
    readonly property real originX: OverlayState.origin.x
    readonly property real originY: OverlayState.origin.y
    property int selected: -1

    onOpenChanged: if (ready) updateMenu()
    onReadyChanged: if (ready) updateMenu()

    function updateMenu()
    {
        if (!open) return;
        selected = -1;
        Qt.callLater(() => { if (desktopMenu.open) content.forceActiveFocus(); });
    }

    function activate(index)
    {
        hide();
        if (index === 0) OverlayState.show("wallpapers");
        else if (index === 1) OverlayState.show("settings");
        else if (index === 2) Qt.callLater(() => Quickshell.reload(true));
    }

    Item
    {
        id: content
        anchors.fill: parent
        focus: true

        Keys.onPressed: event =>
        {
            if (event.key === Qt.Key_Escape) desktopMenu.hide();
            else if (event.key === Qt.Key_Down) desktopMenu.selected = (desktopMenu.selected + 1) % 3;
            else if (event.key === Qt.Key_Up) desktopMenu.selected = desktopMenu.selected < 0 ? 2 : (desktopMenu.selected + 2) % 3;
            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && desktopMenu.selected >= 0) desktopMenu.activate(desktopMenu.selected);
            else return;
            event.accepted = true;
        }

        MouseArea
        {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: desktopMenu.hide()
        }

        MenuReveal
        {
            id: card
            objectName: "desktopMenuCard"

            x: Math.max(8, Math.min(desktopMenu.originX, content.width - width - 8))
            y: Math.max(8, Math.min(desktopMenu.originY, content.height - height - 8))
            width: Math.min(240, Math.max(0, content.width - 16))
            height: entries.implicitHeight + 16
            radius: Theme.radiusLarge
            color: Theme.colorSolid
            progress: Config.animationsEnabled ? desktopMenu.reveal : desktopMenu.open ? 1 : 0
            origin: Qt.point((desktopMenu.originX - x) / Math.max(1, width), (desktopMenu.originY - y) / Math.max(1, height))

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            Column
            {
                id: entries
                x: 8
                y: 8
                width: parent.width - 16
                enabled: desktopMenu.open

                ButtonList
                {
                    icon: Icon.wallpapers
                    text: Tr.tr("common.wallpapers")
                    selected: desktopMenu.selected === 0
                    onClicked: desktopMenu.activate(0)
                }
                ButtonList
                {
                    icon: Icon.settings
                    text: Tr.tr("common.settings")
                    selected: desktopMenu.selected === 1
                    onClicked: desktopMenu.activate(1)
                }
                MenuSeparator { }
                ButtonList
                {
                    icon: Icon.reload
                    text: Tr.tr("common.reloadShell")
                    selected: desktopMenu.selected === 2
                    onClicked: desktopMenu.activate(2)
                }
            }
        }
    }
}
