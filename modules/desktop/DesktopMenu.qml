pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

import "../components"
import "../components/bar"
import "../core"

PanelWindow
{
    id: desktopMenu

    property bool open: false
    property real originX: 0
    property real originY: 0
    property int selected: -1

    function show(x, y)
    {
        MenuState.close();
        originX = x;
        originY = y;
        selected = -1;
        open = true;
        Qt.callLater(() => content.forceActiveFocus());
    }

    function activate(index)
    {
        open = false;
        if (index === 0) OverlayState.show("wallpapers");
        else if (index === 1) OverlayState.show("settings");
        else if (index === 2) Qt.callLater(() => Quickshell.reload(true));
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: open || card.opacity > 0
    mask: Region { item: desktopMenu.open ? content : null }

    Connections
    {
        target: OverlayState
        function onSettingsActiveChanged() { if (OverlayState.settingsActive) desktopMenu.open = false }
        function onWallpapersActiveChanged() { if (OverlayState.wallpapersActive) desktopMenu.open = false }
        function onLauncherActiveChanged() { if (OverlayState.launcherActive) desktopMenu.open = false }
        function onPowerActiveChanged() { if (OverlayState.powerActive) desktopMenu.open = false }
    }

    Item
    {
        id: content
        anchors.fill: parent
        focus: true

        Keys.onPressed: event =>
        {
            if (event.key === Qt.Key_Escape) desktopMenu.open = false;
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
            onClicked: desktopMenu.open = false
        }

        Rectangle
        {
            id: card

            x: Math.max(8, Math.min(desktopMenu.originX, content.width - width - 8))
            y: Math.max(8, Math.min(desktopMenu.originY, content.height - height - 8))
            width: Math.round(240 * Config.themeScale)
            height: entries.implicitHeight + 16
            radius: Theme.radiusLarge
            color: Theme.colorSolid
            border.color: Theme.colorLine
            border.width: Theme.borderWidth

            property real reveal: desktopMenu.open ? 1 : 0
            opacity: reveal
            scale: Config.animationsFluid ? 0.94 + reveal * 0.06 : 1
            transformOrigin: Item.TopLeft
            transform: Translate { y: Config.animationsFluid ? (1 - card.reveal) * -8 : 0 }

            Ease on reveal
            {
                duration: desktopMenu.open ? Theme.animationDurationOpen : Theme.animationDurationClose
                curve: desktopMenu.open ? Theme.easingEmphasized : Theme.easingAccelerate
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
                    text: Tr.tr("menu.user.wallpapers")
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
                    text: Tr.tr("menu.user.reloadShell")
                    selected: desktopMenu.selected === 2
                    onClicked: desktopMenu.activate(2)
                }
            }
        }
    }
}
