pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../../../common"
import "../../../../core"
import "../../../../services"

Rectangle
{
    id: panel
    objectName: "islandNotifications"

    implicitHeight: content.implicitHeight + 20
    radius: Theme.menuControlRadius
    color: Theme.menuControlBackground

    property real now: Date.now()
    readonly property var groups: ServiceNotifications.groups
    readonly property var groupsByKey: new Map(groups.map(group => [group.key, group]))

    Timer { interval: 30000; running: panel.visible; repeat: true; onTriggered: panel.now = Date.now() }

    Column
    {
        id: content

        x: 10
        y: 10
        width: parent.width - 20
        spacing: 9

        Item
        {
            width: parent.width
            height: 28

            ShellIcon
            {
                id: bell
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                icon: Icon.bell
                size: 15
            }
            ShellText
            {
                anchors { left: bell.right; leftMargin: 7; right: dnd.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                label: Tr.tr("common.notifications")
                font.weight: Font.DemiBold
                color: Theme.text1
            }
            Toggle
            {
                id: dnd
                objectName: "notificationsDnd"
                anchors { right: clear.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                checked: ServiceNotifications.dnd
                Accessible.name: Tr.tr("common.doNotDisturb")
                onToggled: value => ServiceNotifications.setDnd(value)
            }
            Button
            {
                id: clear
                objectName: "notificationsClearAll"
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 28
                height: 28
                radius: height / 2
                text: Tr.tr("menu.notifications.clearAll")
                icon: Icon.trash
                iconOnly: true
                hoverScale: 1
                onClicked: ServiceNotifications.dismissAll()
            }
        }

        MenuDropdown
        {
            objectName: "notificationsDndDuration"
            width: parent.width
            visible: ServiceNotifications.dnd
            presented: panel.visible
            options: ServiceNotifications.dndOptions
            current: ServiceNotifications.dndMinutes
            onSelected: value => ServiceNotifications.setDnd(true, value)
        }

        Repeater
        {
            model: ScriptModel { values: panel.groups.map(group => group.key) }

            NotificationGroup
            {
                required property string modelData
                width: content.width
                model: panel.groupsByKey.get(modelData) ?? null
                now: panel.now
                onActivated: MenuState.close()
            }
        }
    }
}
