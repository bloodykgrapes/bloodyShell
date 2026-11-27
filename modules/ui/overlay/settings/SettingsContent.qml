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
    readonly property var pages: Registry.settings
    readonly property var tabs: Registry.settingsPages
    readonly property int current: Math.max(0, Math.min(pages.length - 1, OverlayState.settingsPage))
    readonly property int currentTab: Registry.settingsTabIndex(current)
    readonly property var currentPage: pages[current]
    readonly property var parentPage: Registry.settingsParent(current)

    function select(index) { OverlayState.settingsPage = Math.max(0, Math.min(pages.length - 1, index)) }
    function selectID(id)
    {
        const index = Registry.settingsIndex(id);
        if (index >= 0) select(index);
    }
    function goBack() { if (parentPage) selectID(parentPage.id) }
    function moveTab(offset)
    {
        const index = Math.max(0, Math.min(tabs.length - 1, currentTab + offset));
        if (tabs[index]) selectID(tabs[index].id);
    }

    clip: true

    focus: true
    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: event =>
    {
        if (event.key === Qt.Key_Escape && settingsContent.parentPage) goBack();
        else if (event.key === Qt.Key_Escape)     OverlayState.hide("settings");
        else if (!settingsContent.activeFocus)               return;
        else if (event.key === Qt.Key_Up)         moveTab(-1);
        else if (event.key === Qt.Key_Down)       moveTab(1);
        else if (event.key === Qt.Key_Home)       selectID(tabs[0].id);
        else if (event.key === Qt.Key_End)        selectID(tabs[tabs.length - 1].id);
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
        current: settingsContent.currentTab
        onSelected: id =>
        {
            settingsContent.selectID(id);
            settingsContent.forceActiveFocus();
        }
    }

    Item
    {
        id: pagesView

        property int  shown: -1
        property bool flip: false

        function present(index)
        {
            if (index === shown) return;

            const direction = shown < 0 ? 0 : index > shown ? 1 : -1;
            shown = index;
            flip = !flip;

            (flip ? slotB : slotA).leave(direction);
            const entry = settingsContent.pages[index];
            const parent = Registry.settingsParent(index);
            (flip ? slotA : slotB).enter(entry.page, direction, entry.icon, parent ? parent.title : "");
        }

        x: sidebar.x + sidebar.width + 4
        y: 1
        width: Math.max(0, parent.width - x - 1)
        height: Math.max(0, parent.height - 2)
        clip: true

        Component.onCompleted: present(settingsContent.current)
        Connections { target: settingsContent; function onCurrentChanged() { pagesView.present(settingsContent.current) } }

        SettingsPageSlot { id: slotA; anchors.fill: parent; onBackRequested: settingsContent.goBack() }
        SettingsPageSlot { id: slotB; anchors.fill: parent; onBackRequested: settingsContent.goBack() }
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
