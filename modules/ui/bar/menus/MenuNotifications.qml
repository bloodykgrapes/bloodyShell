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

    Component.onCompleted: ServiceNotifications.markRead()

    function clearAll()
    {
        if (!Config.animationsEnabled) { ServiceNotifications.dismissAll(); return; }
        for (let i = 0; i < groups.count; i++) { const g = groups.itemAt(i); if (g) g.dismissAll(false); }
        clearLater.restart();
    }

    Timer { id: clearLater; interval: Theme.animationDurationClose + 260; onTriggered: ServiceNotifications.dismissAll() }

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

        MenuToggle
        {
            icon: Icon.notifications
            text: Tr.tr("common.doNotDisturb")
            checked: ServiceNotifications.dnd
            onToggle: value => ServiceNotifications.dnd = value
        }

        MenuSeparator {}
    }

    RevealSection
    {
        shown: menuNotifications.presented
        order: 1

        Item
        {
            visible: ServiceNotifications.count === 0
            width: parent.width
            height: 116

            Column
            {
                anchors.centerIn: parent
                spacing: 6

                ShellIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: Icon.bellOFF; size: 26; opacity: 0.45 }
                ShellText { anchors.horizontalCenter: parent.horizontalCenter; label: Tr.tr("menu.notifications.noNotifications"); size: 13; color: Theme.text2 }
                ShellText { anchors.horizontalCenter: parent.horizontalCenter; label: Tr.tr("menu.notifications.emptyHint"); size: 11; color: Theme.text4 }
            }
        }
    }

    RevealSection
    {
        shown: menuNotifications.presented
        order: 2

        Flickable
        {
            id: scroller

            visible: ServiceNotifications.count > 0

            readonly property real overhang: 8
            x: -overhang
            width: parent.width + overhang * 2
            height: Math.min(contentHeight, Math.round(480 * Config.themeScale))
            contentHeight: list.implicitHeight + 4
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            Column
            {
                id: list
                x: scroller.overhang
                y: 2
                width: scroller.width - scroller.overhang * 2
                spacing: 8

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

    RevealSection
    {
        shown: menuNotifications.presented
        order: 3

        MenuSeparator { visible: ServiceNotifications.count > 0 }

        MenuItem
        {
            icon: Icon.trash
            text: Tr.tr("menu.notifications.clearAll")
            visible: ServiceNotifications.count > 0
            onClicked: menuNotifications.clearAll()
        }
    }
}
