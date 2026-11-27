pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"

SettingsPopup
{
    id: menu

    property var application: null
    property Item sourceItem: null
    property point origin: Qt.point(0, 0)
    readonly property string appId: application ? application.id : ""
    readonly property var startupEntry: ServiceApplications.autostartEntries.find(entry =>
        entry.appId === appId.replace(/\.desktop$/, "") || entry.id === appId)
    signal deleteRequested(var application)

    component Action: ButtonList
    {
        id: action
        height: 42
        filled: true
        onActiveFocusChanged: if (activeFocus) body.revealBodyItem(action)
    }

    component ToggleAction: Action
    {
        id: toggleAction
        property alias checked: toggle.checked
        property alias toggleName: toggle.objectName
        signal toggled(bool value)

        persistentActions: true
        Accessible.role: Accessible.CheckBox
        Accessible.checkable: true
        Accessible.checked: checked
        Accessible.onToggleAction: if (enabled) toggled(!checked)
        onClicked: toggled(!checked)
        Toggle
        {
            id: toggle
            activeFocusOnTab: false
            Accessible.name: toggleAction.text
            onToggled: value => toggleAction.toggled(value)
        }
    }

    objectName: "applicationContextMenu"
    width: Math.min(300, Math.max(0, parent.width - 16))
    implicitHeight: body.implicitHeight + 16
    dim: false
    x: Math.max(8, Math.min(origin.x, parent.width - width - 8))
    y: Math.max(8, Math.min(origin.y, parent.height - height - 8))

    function openFor(app, item, localX, localY)
    {
        application = app;
        sourceItem = item;
        origin = item.mapToItem(parent, localX, localY);
        open();
    }

    onOpened:
    {
        focusOrigin = sourceItem;
        pinItem.focusFor(keyboardNavigation ? Qt.TabFocusReason : Qt.MouseFocusReason);
    }

    contentItem: MenuReveal
    {
        objectName: "applicationMenuReveal"
        progress: Config.animationsEnabled ? menu.reveal : menu.presenting ? 1 : 0
        origin: Qt.point((menu.origin.x - menu.x) / Math.max(1, menu.width), (menu.origin.y - menu.y) / Math.max(1, menu.height))
        color: Theme.popupColorBackground
        useSurfaceMaterial: false

        SettingsPopupLayout
        {
            id: body
            x: 8; y: 8
            width: parent.width - 16
            height: parent.height - 16
            spacing: 2
            contentSpacing: 2
            bodyInset: 5
            Accessible.role: Accessible.PopupMenu
            Accessible.name: menu.application ? menu.application.name : ""

            header: Item
            {
                width: parent.width
                height: 64
                Rectangle
                {
                    id: appIcon
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: 12
                    color: Theme.colorField
                    Image
                    {
                        anchors.centerIn: parent
                        width: 28; height: 28
                        source: menu.appId ? ServiceApplications.iconFor(menu.appId) || Icon.settingsApplications : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(56, 56)
                    }
                }
                Column
                {
                    anchors { left: appIcon.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 3
                    ShellText { width: parent.width; label: menu.application ? menu.application.name : ""; font.weight: Font.DemiBold; size: 13; color: Theme.text1 }
                    ShellText { width: parent.width; label: menu.appId; size: 11; color: Theme.text3 }
                }
            }
            MenuSeparator {}
            ToggleAction
            {
                id: pinItem
                objectName: "applicationPin"
                text: Tr.tr("settings.applications.dockPin")
                icon: Icon.pin
                checked: ServiceDock.isPinned(menu.appId)
                toggleName: "applicationPinToggle"
                onToggled: ServiceDock.togglePin(menu.appId)
                KeyNavigation.down: notificationsItem
                KeyNavigation.up: deleteItem
            }
            ToggleAction
            {
                id: notificationsItem
                objectName: "applicationNotifications"
                text: Tr.tr("common.notifications")
                icon: Icon.bellON
                checked: ServiceNotifications.enabledFor(menu.appId)
                toggleName: "applicationNotificationsToggle"
                onToggled: value => ServiceNotifications.setEnabledFor(menu.appId, value)
                KeyNavigation.up: pinItem
                KeyNavigation.down: startupItem.visible ? startupItem : launchItem
            }
            ToggleAction
            {
                id: startupItem
                objectName: "applicationAutostart"
                visible: menu.appId !== "" && menu.startupEntry?.system !== true
                enabled: !ServiceApplications.autostartBusy
                text: Tr.tr("settings.autostart.title")
                icon: Icon.autostart
                checked: menu.startupEntry?.enabled ?? false
                toggleName: "applicationAutostartToggle"
                KeyNavigation.up: notificationsItem
                KeyNavigation.down: launchItem
                onToggled: value =>
                {
                    if (menu.startupEntry) ServiceApplications.setAutostartEnabled(menu.startupEntry.id, value);
                    else if (value) ServiceApplications.addAutostart(menu.appId);
                }
            }
            MenuSeparator {}
            Action
            {
                id: launchItem
                objectName: "applicationLaunch"
                text: Tr.tr("settings.applications.launch")
                icon: Icon.mediaPlay
                enabled: menu.application !== null
                KeyNavigation.up: startupItem.visible ? startupItem : notificationsItem
                KeyNavigation.down: deleteItem
                onClicked:
                {
                    const app = menu.application;
                    menu.close();
                    ServiceApplications.launchEntry(app);
                    OverlayState.hide("settings");
                }
            }
            Action
            {
                id: deleteItem
                objectName: "applicationDelete"
                text: Tr.tr("settings.applications.delete")
                icon: Icon.trash
                danger: true
                KeyNavigation.up: launchItem
                KeyNavigation.down: pinItem
                onClicked:
                {
                    const app = menu.application;
                    menu.close();
                    menu.deleteRequested(app);
                }
            }
        }
    }
}
