pragma ComponentBehavior: Bound

import QtQuick

import "../../../common"
import "../../../core"
import "components"

Item
{
    id: settingsContent

    property bool paintBackground: true
    property Item navigationSurfaceHost: null
    readonly property alias navigationSurface: sidebar.surface
    readonly property var tabs: Registry.settings
    readonly property int current: Math.max(0, Math.min(tabs.length - 1, OverlayState.settingsPage))

    function select(index) { OverlayState.settingsPage = Math.max(0, Math.min(tabs.length - 1, index)) }

    clip: true

    focus: true
    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: event =>
    {
        if (event.key === Qt.Key_Escape)          OverlayState.hide("settings");
        else if (!settingsContent.activeFocus)               return;
        else if (event.key === Qt.Key_Up)         select(current - 1);
        else if (event.key === Qt.Key_Down)       select(current + 1);
        else if (event.key === Qt.Key_Home)       select(0);
        else if (event.key === Qt.Key_End)        select(tabs.length - 1);
        else return;
        event.accepted = true;
    }

    Loader
    {
        anchors.fill: parent
        active: settingsContent.paintBackground
        sourceComponent: SurfaceCutout
        {
            color: Theme.settingsColorBackground
            cutout: settingsContent.navigationSurface
        }
    }

    MouseArea { anchors.fill: parent; onClicked: settingsContent.forceActiveFocus() }

    SettingsTabGroup
    {
        id: sidebar
        objectName: "settingsSidebar"
        x: 8
        y: 8
        width: Math.min(settingsContent.width < 900 ? Theme.settingsSidebar - 16 : Theme.settingsSidebar, Math.max(172, settingsContent.width * 0.3))
        height: Math.max(0, parent.height - 16)
        surfaceHost: settingsContent.navigationSurfaceHost

        tabs: settingsContent.tabs
        groups: Registry.settingsGroups
        current: settingsContent.current
        onSelected: index =>
        {
            settingsContent.select(index);
            settingsContent.forceActiveFocus();
        }
    }

    Item
    {
        id: pages

        property int  shown: -1
        property bool flip: false

        function present(index)
        {
            if (index === shown) return;

            const direction = shown < 0 ? 0 : index > shown ? 1 : -1;
            shown = index;
            flip = !flip;

            (flip ? slotB : slotA).leave(direction);
            const entry = settingsContent.tabs[index];
            (flip ? slotA : slotB).enter(entry.page, direction, entry.icon);
        }

        x: sidebar.x + sidebar.width + 4
        y: 1
        width: Math.max(0, parent.width - x - 1)
        height: Math.max(0, parent.height - 2)
        clip: true

        Component.onCompleted: present(settingsContent.current)
        Connections { target: settingsContent; function onCurrentChanged() { pages.present(settingsContent.current) } }

        SettingsPageSlot { id: slotA; anchors.fill: parent }
        SettingsPageSlot { id: slotB; anchors.fill: parent }
    }

    Button
    {
        iconOnly: true
        objectName: "settingsClose"
        anchors { top: parent.top; right: parent.right; margins: 22 }
        z: 30
        width: 30
        height: 30
        radius: 10
        icon: Icon.close
        iconSize: 14
        text: Tr.tr("common.close")
        onClicked: OverlayState.hide("settings")
    }

    readonly property alias popupLayer: popupLayer
    Item { id: popupLayer; anchors.fill: parent; z: 1000 }
}
