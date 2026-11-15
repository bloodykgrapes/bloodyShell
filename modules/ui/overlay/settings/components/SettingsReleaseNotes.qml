pragma ComponentBehavior: Bound

import QtQuick

import "../../../../core"
import "../../../../common"
import "../../../../src/ReleaseNotes.js" as Notes

Column
{
    id: releaseNotes

    property string text: ""
    property string baseUrl: ""
    readonly property var blocks: Notes.parse(text, baseUrl)
    signal linkActivated(string link)

    spacing: 12

    Repeater
    {
        model: releaseNotes.blocks

        Column
        {
            id: block
            required property var modelData
            width: releaseNotes.width
            spacing: 8

            Text
            {
                objectName: "releaseMarkdown"
                width: parent.width
                visible: block.modelData.kind === "text"
                text: visible ? block.modelData.text : ""
                baseUrl: releaseNotes.baseUrl
                textFormat: Text.MarkdownText
                wrapMode: Text.Wrap
                color: Theme.text2
                linkColor: Theme.colorAttention
                font.pixelSize: 12
                font.family: Theme.fontText
                lineHeight: 1.15
                onLinkActivated: link => releaseNotes.linkActivated(link)
                HoverHandler { cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor }
            }

            Flow
            {
                id: gallery
                objectName: "releaseGallery"
                width: parent.width
                visible: block.modelData.kind === "gallery"
                readonly property int columns: width >= 480 && images.count > 1 ? 2 : 1
                spacing: 10

                Repeater
                {
                    id: images
                    model: gallery.visible ? block.modelData.images : []

                    Rectangle
                    {
                        id: tile
                        required property var modelData
                        objectName: "releaseImageTile"
                        width: Math.max(0, (gallery.width - (gallery.columns - 1) * gallery.spacing) / gallery.columns)
                        height: preview.status === Image.Error ? 96 : Math.round(Math.max(0, width - 16) * ratio) + 16
                        readonly property real ratio: preview.implicitWidth > 0 && preview.implicitHeight > 0
                            ? Math.min(1.5, preview.implicitHeight / preview.implicitWidth) : 0.6
                        radius: 12
                        color: Theme.colorField
                        border.width: 1
                        border.color: area.containsMouse || activeFocus ? Theme.colorAttention : Theme.colorHairline
                        activeFocusOnTab: preview.status === Image.Ready
                        Accessible.role: Accessible.Link
                        Accessible.name: modelData.alt || Tr.tr("common.preview")
                        Accessible.onPressAction: releaseNotes.linkActivated(tile.modelData.source)
                        Keys.onReturnPressed: releaseNotes.linkActivated(tile.modelData.source)
                        Keys.onSpacePressed: event => {
                            if (!event.isAutoRepeat) releaseNotes.linkActivated(tile.modelData.source);
                            event.accepted = true;
                        }

                        Image
                        {
                            id: preview
                            objectName: "releaseImage"
                            anchors.fill: parent
                            anchors.margins: 8
                            source: tile.modelData.source
                            sourceSize.width: 1600
                            asynchronous: true
                            autoTransform: true
                            fillMode: Image.PreserveAspectFit
                        }

                        ShellText
                        {
                            anchors.centerIn: parent
                            width: Math.max(0, parent.width - 24)
                            horizontalAlignment: Text.AlignHCenter
                            visible: preview.status !== Image.Ready
                            label: preview.status === Image.Loading ? Tr.tr("common.loading")
                                : tile.modelData.alt || Tr.tr("common.preview")
                            color: Theme.text3
                        }

                        MouseArea
                        {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: releaseNotes.linkActivated(tile.modelData.source)
                        }
                    }
                }
            }

            Text
            {
                objectName: "releaseCaption"
                width: parent.width
                visible: block.modelData.kind === "gallery" && text !== ""
                text: block.modelData.caption || ""
                textFormat: Text.RichText
                baseUrl: releaseNotes.baseUrl
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.text3
                linkColor: Theme.colorAttention
                font.pixelSize: 11
                font.family: Theme.fontText
                onLinkActivated: link => releaseNotes.linkActivated(link)
            }
        }
    }
}
