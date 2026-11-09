pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

import "../../../common"
import "../../../core"
import "../../../services"

Column
{
    id: lockNotifications

    readonly property int count: notes.count
    property int limit: 3
    readonly property bool showContent: Config.lockNotificationsContent

    property real now: Date.now()
    RenderActivity { id: activity; target: lockNotifications }
    Timer { interval: 30000; running: activity.active; repeat: true; onTriggered: lockNotifications.now = Date.now() }

    spacing: 10

    Repeater
    {
        id: notes
        model: ServiceNotifications.history.slice(0, lockNotifications.limit)

        Item
        {
            id: note
            required property var modelData
            required property int index
            readonly property var n: modelData

            width: lockNotifications.width
            height: Math.max(38, text.implicitHeight) + 28
            opacity: 1 - 0.25 * index

            LockSurface { anchors.fill: parent; radius: 18 }

            ClippingRectangle
            {
                id: icon
                x: 14; y: 14
                width: 34; height: 34
                radius: 10
                color: Theme.lockStrong

                readonly property string iconName: note.n ? String(note.n.appIcon || "") : ""
                readonly property string source: !note.n ? ""
                    : lockNotifications.showContent && note.n.image ? note.n.image
                    : iconName === "" ? ""
                    : iconName.startsWith("/") ? "file://" + iconName : ServiceAppearance.iconPath(iconName)

                Image { anchors.centerIn: parent; visible: picture.status !== Image.Ready; source: Icon.notifications; width: 17; height: 17; sourceSize: Qt.size(34, 34) }
                Image
                {
                    id: picture
                    objectName: "lockNotificationImage"
                    anchors.fill: parent
                    source: icon.source
                    sourceSize: Qt.size(68, 68)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Column
            {
                id: text
                anchors { left: icon.right; leftMargin: 12; right: parent.right; rightMargin: 14; top: parent.top; topMargin: 14 }
                spacing: 4

                Item
                {
                    width: parent.width
                    height: app.implicitHeight
                    ShellText
                    {
                        id: app
                        anchors { left: parent.left; right: age.left; rightMargin: 10 }
                        label: note.n ? (note.n.appName || Tr.tr("common.notifications")) : ""
                        size: 11
                        color: Theme.lockText3
                        font.weight: Font.Medium
                    }
                    ShellText
                    {
                        id: age
                        anchors { right: parent.right; verticalCenter: app.verticalCenter }
                        label: ServiceNotifications.age(note.n, lockNotifications.now)
                        size: 10
                        color: Theme.lockText3
                    }
                }
                ShellText
                {
                    objectName: "lockNotificationSummary"
                    width: parent.width
                    label: lockNotifications.showContent && note.n ? (note.n.summary || "") : Tr.tr("settings.lock.contentHidden")
                    size: 13
                    color: Theme.lockText1
                    font.weight: Font.DemiBold
                }
                ShellText
                {
                    objectName: "lockNotificationBody"
                    width: parent.width
                    visible: lockNotifications.showContent && label !== ""
                    label: lockNotifications.showContent && note.n ? (note.n.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() : ""
                    size: 12
                    color: Theme.lockText2
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
