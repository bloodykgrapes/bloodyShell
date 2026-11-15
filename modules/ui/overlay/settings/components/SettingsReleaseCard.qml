import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Item
{
    id: notesItem
    objectName: "releaseNotesCard"

    required property var release
    required property string repo
    property bool collapsible: true
    property bool expanded: false

    readonly property real collapsedHeight: 180
    readonly property bool tall: body.implicitHeight > collapsedHeight + 40
    readonly property bool collapsed: collapsible && tall && !expanded

    function date(iso)
    {
        const value = new Date(iso);
        return isNaN(value.getTime()) ? "" : value.toLocaleDateString(Tr.locale, "d MMM yyyy");
    }

    width: parent ? parent.width : 400
    height: column.implicitHeight + 32

    SettingsTile { row: notesItem }

    Column
    {
        id: column

        x: 18
        y: 16
        width: parent.width - 36
        spacing: 10

        Item
        {
            width: parent.width
            height: Math.max(heading.implicitHeight, github.height)

            Row
            {
                id: heading

                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                ShellText
                {
                    anchors.verticalCenter: parent.verticalCenter
                    label: notesItem.release.name
                    size: 14
                    color: Theme.text1
                    font.bold: true
                }
                Chip { anchors.verticalCenter: parent.verticalCenter; visible: notesItem.release.prerelease; text: Tr.tr("settings.updates.preRelease"); tint: Theme.colorWarning }
                ShellText
                {
                    anchors.verticalCenter: parent.verticalCenter
                    label: notesItem.date(notesItem.release.date)
                    size: 11
                    color: Theme.text3
                }
            }

            SettingsButton
            {
                id: github

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: notesItem.release.url !== ""
                text: Tr.tr("settings.updates.viewOnGithub")
                onClicked: Qt.openUrlExternally(notesItem.release.url)
            }
        }

        Item
        {
            width: parent.width
            height: notesItem.collapsed ? notesItem.collapsedHeight : body.implicitHeight
            clip: true
            Glide on height {}

            SettingsReleaseNotes
            {
                id: body
                objectName: "releaseNotesBody"

                width: parent.width
                text: notesItem.release.notes !== "" ? notesItem.release.notes : "_" + Tr.tr("settings.updates.noReleaseNotes") + "_"
                baseUrl: "https://raw.githubusercontent.com/" + notesItem.repo + "/" + encodeURIComponent(notesItem.release.tag) + "/"
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Rectangle
            {
                visible: notesItem.collapsed
                anchors.bottom: parent.bottom
                width: parent.width
                height: 48
                gradient: Gradient
                {
                    GradientStop { position: 0; color: Qt.rgba(Theme.settingsColorCard.r, Theme.settingsColorCard.g, Theme.settingsColorCard.b, 0) }
                    GradientStop { position: 1; color: Theme.settingsColorCard }
                }
            }
        }

        SettingsButton
        {
            objectName: "releaseNotesToggle"
            visible: notesItem.collapsible && notesItem.tall
            text: notesItem.expanded ? Tr.tr("settings.updates.showLess") : Tr.tr("settings.updates.showMore")
            icon: notesItem.expanded ? Icon.chevronUp : Icon.chevronDown
            onClicked: notesItem.expanded = !notesItem.expanded
        }
    }
}
