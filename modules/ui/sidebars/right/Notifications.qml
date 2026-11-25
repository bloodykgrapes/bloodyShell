pragma ComponentBehavior: Bound

import QtQuick

import "../../../common"
import "../../../core"
import "../../../services"

Column
{
    id: notifications
    objectName: "sidebarNotifications"
    property bool active: false
    property bool opening: false
    width: parent ? parent.width : 344
    spacing: 12

    function updateActivity()
    {
        opening = active && Config.animationsFluid;
        if (active)
        {
            now = Date.now();
            ServiceNotifications.markRead();
            if (opening) openingTimer.restart();
        }
    }
    onActiveChanged: updateActivity()
    Component.onCompleted: updateActivity()
    Timer { id: openingTimer; interval: 700; onTriggered: notifications.opening = false }
    Connections
    {
        target: ServiceNotifications
        function onUnreadCounterChanged() { if (notifications.active && ServiceNotifications.unreadCounter > 0) ServiceNotifications.markRead(); }
    }
    Component.onDestruction: flushClear()

    property var pendingClear: []

    function clearAll()
    {
        if (pendingClear.length > 0 || ServiceNotifications.count === 0) return;
        if (!Config.animationsEnabled) { ServiceNotifications.dismissAll(); return; }
        pendingClear = ServiceNotifications.history.slice();
        for (let i = 0; i < groups.count; i++) { const g = groups.itemAt(i); if (g) g.dismissAll(false); }
        clearLater.restart();
    }
    function flushClear()
    {
        const pending = pendingClear;
        pendingClear = [];
        for (const notification of pending) ServiceNotifications.dismiss(notification);
    }

    Timer { id: clearLater; interval: Theme.animationDurationClose + 260; onTriggered: notifications.flushClear() }

    property var expanded: ({})
    function toggle(key)
    {
        const next = Object.assign({}, expanded);
        next[key] = !next[key];
        expanded = next;
    }

    property real now: Date.now()
    Timer { interval: 30000; running: notifications.active; repeat: true; onTriggered: notifications.now = Date.now() }

    RevealSection
    {
        shown: notifications.active
        order: 0

        Rectangle
        {
            objectName: "notificationsFocusCard"
            width: parent.width
            height: focusControls.implicitHeight + 24
            radius: Theme.menuControlRadius
            color: Theme.menuControlBackground

            Column
            {
                id: focusControls
                x: 12; y: 12
                width: parent.width - 24
                spacing: 10

                Row
                {
                    width: parent.width
                    height: 32
                    spacing: 10

                    Rectangle
                    {
                        width: 32; height: 32; radius: 10
                        color: ServiceNotifications.dnd ? Theme.menuControlSelected : Theme.colorField
                        ShellIcon { anchors.centerIn: parent; icon: Icon.bellOFF; size: 18 }
                    }
                    Column
                    {
                        width: Math.max(0, parent.width - 32 - dndSwitch.width - parent.spacing * 2)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        ShellText { width: parent.width; label: Tr.tr("common.doNotDisturb"); size: 12; font.weight: Font.DemiBold; color: Theme.text1 }
                        ShellText { width: parent.width; label: ServiceNotifications.dndStatus; size: 10; color: Theme.text3 }
                    }
                    Toggle
                    {
                        id: dndSwitch
                        objectName: "notificationsDnd"
                        anchors.verticalCenter: parent.verticalCenter
                        Accessible.name: Tr.tr("common.doNotDisturb")
                        checked: ServiceNotifications.dnd
                        onToggled: value => ServiceNotifications.setDnd(value)
                    }
                }

                MenuDropdown
                {
                    objectName: "notificationsDndDuration"
                    visible: ServiceNotifications.dnd
                    width: parent.width
                    presented: notifications.active
                    options: ServiceNotifications.dndOptions
                    current: ServiceNotifications.dndMinutes
                    onSelected: value => ServiceNotifications.setDnd(true, value)
                }
            }
        }
    }

    RevealSection
    {
        shown: notifications.active
        order: 1
        visible: ServiceNotifications.count === 0

        Item
        {
            objectName: "notificationsEmptyState"
            width: parent.width
            height: empty.implicitHeight + 32

            Column
            {
                id: empty
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 8

                Rectangle
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40; height: 40; radius: 14
                    color: Theme.menuControlBackground
                    ShellIcon { anchors.centerIn: parent; icon: Icon.bellON; size: 20; opacity: 0.65 }
                }
                ShellText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; label: Tr.tr("menu.notifications.noNotifications"); size: 12; color: Theme.text1; font.weight: Font.Medium }
                ShellText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; label: Tr.tr("menu.notifications.emptyHint"); size: 11; color: Theme.text3 }
            }
        }
    }

    RevealSection
    {
        shown: notifications.active
        order: 2
        visible: ServiceNotifications.count > 0
        spacing: 4

        Item
        {
            width: parent.width
            height: 32

            Row
            {
                anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                spacing: 8
                ShellText { anchors.verticalCenter: parent.verticalCenter; label: Tr.tr("notifications.recent"); size: 11; color: Theme.text3; font.weight: Font.Medium }
                ShellText { anchors.verticalCenter: parent.verticalCenter; label: String(ServiceNotifications.count); size: 10; color: Theme.text3 }
            }
            Button
            {
                objectName: "notificationsClearAll"
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                height: 28
                radius: 8
                text: Tr.tr("menu.notifications.clearAll")
                textSize: 11
                icon: Icon.trash
                iconSize: 11
                color: "transparent"
                enabled: notifications.pendingClear.length === 0
                onClicked: notifications.clearAll()
            }
        }

        Column
        {
            width: parent.width
            spacing: 12
            Repeater
            {
                id: groups
                model: ServiceNotifications.groups

                NotificationGroup
                {
                    required property var modelData
                    required property int index
                    model: modelData
                    entering: notifications.opening
                    order: index
                    expanded: notifications.expanded[modelData.key] === true
                    now: notifications.now
                    onToggle: notifications.toggle(modelData.key)
                    onActivated: SidebarState.close()
                }
            }
        }
    }
}
