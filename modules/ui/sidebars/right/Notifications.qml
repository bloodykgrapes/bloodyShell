pragma ComponentBehavior: Bound

import QtQuick

import "../../../common"
import "../../../core"
import "../../../services"
import "../../overlay/settings/components"

Column
{
    id: notifications
    objectName: "sidebarNotifications"
    property bool active: false
    property bool opening: false
    width: parent ? parent.width : 344
    spacing: 8

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

        Column
        {
            width: parent.width
            spacing: 8
            ControlToggle
            {
                objectName: "notificationsDnd"
                width: parent.width
                height: implicitHeight
                icon: Icon.notifications
                text: Tr.tr("common.doNotDisturb")
                subtitle: ServiceNotifications.dndStatus
                checked: ServiceNotifications.dnd
                onToggled: value => ServiceNotifications.setDnd(value)
            }
            SettingsChoices
            {
                objectName: "notificationsDndDuration"
                width: parent.width
                options: ServiceNotifications.dndOptions
                current: ServiceNotifications.dnd ? ServiceNotifications.dndMinutes : -1
                onSelected: value => ServiceNotifications.setDnd(true, value)
            }
        }
    }

    RevealSection
    {
        shown: notifications.active
        order: 1
        visible: ServiceNotifications.count === 0

        Rectangle
        {
            width: parent.width
            height: Math.max(148, empty.implicitHeight + 32)
            radius: 18
            color: Theme.colorField

            Column
            {
                id: empty
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 8

                Rectangle
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 44; height: 44; radius: 16
                    color: Theme.colorHoverStrong
                    ShellIcon { anchors.centerIn: parent; icon: Icon.bellOFF; size: 24 }
                }
                ShellText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; label: Tr.tr("menu.notifications.noNotifications"); size: 13; color: Theme.text1; font.weight: Font.Medium }
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

        MenuLabel
        {
            heading: true
            text: Tr.tr("common.notifications")
            actionText: Tr.tr("menu.notifications.clearAll")
            actionIcon: Icon.trash
            actionEnabled: notifications.pendingClear.length === 0
            onActionTriggered: notifications.clearAll()
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
