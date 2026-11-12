pragma ComponentBehavior: Bound

import QtQuick

import "../../../common"
import "../../../core"
import "../../../services"

Menu
{
    id: menuNotifications
    objectName: "notificationsMenu"

    implicitWidth: 360
    spacing: 8

    Component.onCompleted: ServiceNotifications.markRead()
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

    Timer { id: clearLater; interval: Theme.animationDurationClose + 260; onTriggered: menuNotifications.flushClear() }

    property var expanded: ({})
    function toggle(key)
    {
        const next = Object.assign({}, expanded);
        next[key] = !next[key];
        expanded = next;
    }

    property real now: Date.now()
    Timer { interval: 30000; running: menuNotifications.active; repeat: true; onTriggered: menuNotifications.now = Date.now() }

    RevealSection
    {
        shown: menuNotifications.presented
        order: 0

        ControlToggle
        {
            objectName: "notificationsDnd"
            width: parent.width
            height: implicitHeight
            icon: Icon.notifications
            text: Tr.tr("common.doNotDisturb")
            subtitle: Tr.tr(checked ? "common.enabled" : "common.off")
            checked: ServiceNotifications.dnd
            onToggled: value => ServiceNotifications.dnd = value
        }
    }

    RevealSection
    {
        shown: menuNotifications.presented
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
        shown: menuNotifications.presented
        order: 2
        visible: ServiceNotifications.count > 0
        spacing: 4

        MenuLabel
        {
            heading: true
            text: Tr.tr("common.notifications")
            actionText: Tr.tr("menu.notifications.clearAll")
            actionIcon: Icon.trash
            actionEnabled: menuNotifications.pendingClear.length === 0
            onActionTriggered: menuNotifications.clearAll()
        }

        Flickable
        {
            id: scroller

            visible: ServiceNotifications.count > 0

            readonly property real overhang: 8
            x: -overhang
            width: parent.width + overhang * 2
            height: Math.min(contentHeight, 440)
            contentHeight: list.implicitHeight + 4
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            SmoothScroll { view: scroller }

            Column
            {
                id: list
                x: scroller.overhang
                y: 2
                width: scroller.width - scroller.overhang * 2
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
                        entering: menuNotifications.opening
                        order: index
                        expanded: menuNotifications.expanded[modelData.key] === true
                        now: menuNotifications.now
                        onToggle: menuNotifications.toggle(modelData.key)
                        onActivated: MenuState.close()
                    }
                }
            }
        }
    }

}
