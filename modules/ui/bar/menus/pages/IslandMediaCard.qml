pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

import "../../../../common"
import "../../../../core"
import "../../../../services"

Rectangle
{
    id: card
    objectName: "islandMediaCard"

    implicitHeight: 66
    radius: Theme.menuControlRadius
    color: Theme.menuControlBackground

    ClippingRectangle
    {
        id: cover

        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        width: 44
        height: width
        radius: Theme.radiusSmall
        color: Theme.colorField

        Image
        {
            id: art
            anchors.fill: parent
            source: ServiceMedia.art
            sourceSize: Qt.size(88, 88)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
        ShellIcon { anchors.centerIn: parent; icon: Icon.music; size: 18; visible: art.status !== Image.Ready }
    }

    Column
    {
        anchors
        {
            left: cover.right; leftMargin: 10
            right: transport.left; rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        spacing: 3

        ShellText
        {
            width: parent.width
            label: ServiceMedia.title
            size: 12
            font.weight: Font.DemiBold
            color: Theme.text1
        }
        ShellText
        {
            width: parent.width
            label: ServiceMedia.artist
            size: 10
            color: Theme.text3
        }
    }

    Row
    {
        id: transport
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 4

        component TransportButton: Button
        {
            width: 30
            height: width
            radius: height / 2
            iconOnly: true
            hoverScale: 1
        }

        TransportButton
        {
            visible: card.width >= 265
            enabled: ServiceMedia.player?.canGoPrevious === true
            text: Tr.tr("menu.media.previousTrack")
            icon: Icon.mediaPrevious
            onClicked: ServiceMedia.previous()
        }
        TransportButton
        {
            objectName: "islandMediaPause"
            enabled: ServiceMedia.player?.canTogglePlaying === true
            text: Tr.tr("menu.media.pause")
            icon: Icon.mediaPause
            onClicked: ServiceMedia.toggle()
        }
        TransportButton
        {
            visible: card.width >= 265
            enabled: ServiceMedia.player?.canGoNext === true
            text: Tr.tr("menu.media.nextTrack")
            icon: Icon.mediaNext
            onClicked: ServiceMedia.next()
        }
    }
}
