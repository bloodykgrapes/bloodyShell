pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../animations"
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
    property real progress: 0
    readonly property real shown: Config.animationsEnabled ? progress : open ? 1 : 0

    Ease on progress
    {
        duration: desktopMenu.open ? Theme.animationDurationControl : Theme.animationDurationClose
        curve: desktopMenu.open ? Theme.easingEmphasized : Theme.easingAccelerate
    }
    onOpenChanged: if (ready) updateMenu()
    onReadyChanged: if (ready) updateMenu()

    function updateMenu()
    {
        progress = open ? 1 : 0;
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

        Rectangle
        {
            id: card
            objectName: "desktopMenuCard"

            x: Math.max(8, Math.min(desktopMenu.originX, content.width - width - 8))
            y: Math.max(8, Math.min(desktopMenu.originY, content.height - height - 8))
            width: Math.min(240, Math.max(0, content.width - 16))
            height: entries.implicitHeight + 16
            radius: Theme.radiusLarge
            color: Theme.colorSolid

            readonly property real zoom: 1 - (Config.animationsFluid ? 0.06 : 0.02) * (1 - desktopMenu.shown)
            opacity: desktopMenu.shown
            transform: Scale
            {
                objectName: "desktopMenuScale"
                origin.x: Math.max(0, Math.min(card.width, desktopMenu.originX - card.x))
                origin.y: Math.max(0, Math.min(card.height, desktopMenu.originY - card.y))
                xScale: card.zoom
                yScale: card.zoom
            }

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            Column
            {
                id: entries
                x: 8
                y: 8
                width: parent.width - 16
                enabled: desktopMenu.open

                MenuRow
                {
                    icon: Icon.wallpapers
                    text: Tr.tr("common.wallpapers")
                    selected: desktopMenu.selected === 0
                    onClicked: desktopMenu.activate(0)
                }
                MenuRow
                {
                    icon: Icon.settings
                    text: Tr.tr("common.settings")
                    selected: desktopMenu.selected === 1
                    onClicked: desktopMenu.activate(1)
                }
                MenuSeparator { }
                MenuRow
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
