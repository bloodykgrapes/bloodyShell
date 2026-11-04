import QtQuick
import Quickshell.Widgets

import ".."
import "../../core"
import "../../services"

Column
{
    id: lockNotifications

    readonly property int count: notes.count
    property int limit: 3

    property real now: Date.now()
    Timer { interval: 30000; running: lockNotifications.visible; repeat: true; onTriggered: lockNotifications.now = Date.now() }

    spacing: 14

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
            height: Math.max(icon.height, text.implicitHeight)
            opacity: 1 - 0.25 * index

            ClippingRectangle
            {
                id: icon
                anchors.top: parent.top
                anchors.topMargin: 1
                width: 28
                height: 28
                radius: 8
                color: Theme.lockStrong

                readonly property string source: !note.n ? ""
                    : note.n.image !== "" ? note.n.image
                    : note.n.appIcon === "" ? ""
                    : note.n.appIcon.startsWith("/") ? "file://" + note.n.appIcon : ServiceAppearance.iconPath(note.n.appIcon)

                Image { anchors.centerIn: parent; visible: picture.status !== Image.Ready; source: Icon.notifications; width: 14; height: 14; sourceSize: Qt.size(28, 28) }
                Image
                {
                    id: picture
                    anchors.fill: parent
                    source: icon.source
                    sourceSize: Qt.size(56, 56)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Column
            {
                id: text
                anchors { left: icon.right; leftMargin: 14; right: parent.right }
                spacing: 1

                Item
                {
                    width: parent.width
                    height: summary.implicitHeight
                    ShellText
                    {
                        id: summary
                        anchors { left: parent.left; right: age.left; rightMargin: 10 }
                        label: note.n ? (note.n.summary || note.n.appName || "") : ""
                        size: 13
                        color: Theme.lockText1
                        font.weight: Font.DemiBold
                    }
                    ShellText
                    {
                        id: age
                        anchors { right: parent.right; verticalCenter: summary.verticalCenter }
                        label: ServiceNotifications.age(note.n, lockNotifications.now)
                        size: 11
                        color: Theme.lockText3
                    }
                }
                ShellText
                {
                    width: parent.width
                    label: note.n ? (note.n.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() : ""
                    size: 12
                    color: Theme.lockText2
                }
            }
        }
    }
}
