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
    signal deleteRequested(var application)

    objectName: "applicationContextMenu"
    width: Math.min(300, Math.max(0, parent.width - 16))
    implicitHeight: body.implicitHeight + padding * 2
    padding: 8
    dim: false
    x: Math.max(8, Math.min(origin.x, parent.width - width - 8))
    y: Math.max(8, Math.min(origin.y, parent.height - height - 8))
    transformOrigin: Item.TopLeft

    function openFor(app, item, localX, localY)
    {
        application = app;
        sourceItem = item;
        origin = item.mapToItem(parent, localX, localY);
        open();
    }

    onOpened: pinItem.focusFor(keyboardNavigation ? Qt.TabFocusReason : Qt.MouseFocusReason)
    onClosed: Qt.callLater(() => {
        if (!OverlayState.settingsPopup && sourceItem && sourceItem.visible && sourceItem.enabled)
        {
            const reason = menu.keyboardNavigation ? Qt.TabFocusReason : Qt.MouseFocusReason;
            if (typeof sourceItem.focusFor === "function") sourceItem.focusFor(reason);
            else sourceItem.forceActiveFocus(reason);
        }
    })

    contentItem: Column
    {
        id: body
        spacing: 2

        Item
        {
            width: parent.width
            height: 58
            Image
            {
                id: appIcon
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32
                source: menu.appId ? ServiceApplications.iconFor(menu.appId) || Icon.settingsApplications : ""
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(64, 64)
            }
            Column
            {
                anchors { left: appIcon.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 3
                ShellText { width: parent.width; label: menu.application ? menu.application.name : ""; font.weight: Font.DemiBold; size: 13; color: Theme.text1 }
                ShellText { width: parent.width; label: menu.appId; size: 10; color: Theme.text3 }
            }
        }
        MenuSeparator {}
        MenuItem
        {
            id: pinItem
            objectName: "applicationPin"
            text: Tr.tr("settings.applications.dockPin")
            icon: Icon.pin
            height: 42
            trailingInset: 56
            onClicked: ServiceDock.togglePin(menu.appId)
            KeyNavigation.down: notificationsItem
            KeyNavigation.up: deleteItem
            Accessible.role: Accessible.CheckBox
            Accessible.checkable: true
            Accessible.checked: ServiceDock.isPinned(menu.appId)
            Accessible.onToggleAction: ServiceDock.togglePin(menu.appId)
            Toggle
            {
                objectName: "applicationPinToggle"
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                checked: ServiceDock.isPinned(menu.appId)
                Accessible.name: pinItem.text
                onToggled: ServiceDock.togglePin(menu.appId)
            }
        }
        MenuItem
        {
            id: notificationsItem
            objectName: "applicationNotifications"
            text: Tr.tr("common.notifications")
            icon: Icon.bellON
            height: 42
            trailingInset: 56
            onClicked: ServiceNotifications.setEnabledFor(menu.appId, !ServiceNotifications.enabledFor(menu.appId))
            KeyNavigation.up: pinItem
            KeyNavigation.down: deleteItem
            Accessible.role: Accessible.CheckBox
            Accessible.checkable: true
            Accessible.checked: ServiceNotifications.enabledFor(menu.appId)
            Accessible.onToggleAction: ServiceNotifications.setEnabledFor(menu.appId, !ServiceNotifications.enabledFor(menu.appId))
            Toggle
            {
                objectName: "applicationNotificationsToggle"
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                checked: ServiceNotifications.enabledFor(menu.appId)
                Accessible.name: notificationsItem.text
                onToggled: value => ServiceNotifications.setEnabledFor(menu.appId, value)
            }
        }
        MenuSeparator {}
        MenuItem
        {
            id: deleteItem
            objectName: "applicationDelete"
            text: Tr.tr("settings.applications.delete")
            icon: Icon.trash
            danger: true
            height: 42
            KeyNavigation.up: notificationsItem
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
