import QtQuick

import "../../../common"
import "../../../core"
import "../../../services"

Item
{
    id: overview
    objectName: "lockOverview"
    property real dismiss: 0

    opacity: 1 - dismiss
    visible: dismiss < 1
    enabled: false
    transform: Translate { y: -28 * overview.dismiss }

    Item
    {
        id: area
        anchors { fill: parent; margins: 28; bottomMargin: 64 }

        Column
        {
            objectName: "lockOverviewContent"
            anchors.centerIn: parent
            width: 520
            spacing: 28
            scale: Math.max(0.1, Math.min(1, area.width / width, area.height / implicitHeight))

            LockReveal
            {
                objectName: "lockClockReveal"
                visible: Config.lockClock || Config.lockDate
                LockClock
                {
                    width: parent.width
                    showDate: Config.lockDate
                    showClock: Config.lockClock
                }
            }
            Column
            {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 380
                spacing: 12
                visible: (Config.lockMusic && ServiceMedia.available) || (Config.lockNotifications && notifications.count > 0)

                LockReveal
                {
                    order: 1
                    visible: Config.lockMusic && ServiceMedia.available
                    LockMedia { width: parent.width }
                }
                LockReveal
                {
                    order: 2
                    visible: Config.lockNotifications && notifications.count > 0
                    LockNotifications { id: notifications; width: parent.width }
                }
            }
        }
    }

    ShellText
    {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 28 }
        horizontalAlignment: Text.AlignHCenter
        label: Tr.tr("lock.unlockHint")
        color: Theme.lockText2
        size: 12
    }
}
