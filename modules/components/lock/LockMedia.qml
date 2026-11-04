import QtQuick
import Quickshell.Widgets

import ".."
import "../../core"
import "../../services"

Item
{
    height: 48

    ClippingRectangle
    {
        id: cover
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        height: 48
        radius: 12
        color: Theme.lockStrong

        Image { anchors.centerIn: parent; visible: art.status !== Image.Ready; source: Icon.music; width: 18; height: 18; sourceSize: Qt.size(36, 36) }
        Image
        {
            id: art
            anchors.fill: parent
            source: ServiceMedia.art
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column
    {
        anchors { left: cover.right; leftMargin: 14; right: controls.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 2
        ShellText { width: parent.width; label: ServiceMedia.title; size: 14; color: Theme.lockText1; font.weight: Font.DemiBold }
        ShellText { width: parent.width; label: ServiceMedia.artist; size: 12; color: Theme.lockText2 }
    }

    Row
    {
        id: controls
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 4

        LockButton
        {
            anchors.verticalCenter: parent.verticalCenter
            flat: true; size: 32; iconSize: 14
            icon: Icon.mediaPrevious
            enabled: ServiceMedia.player !== null && ServiceMedia.player.canGoPrevious
            onClicked: ServiceMedia.previous()
        }
        LockButton
        {
            anchors.verticalCenter: parent.verticalCenter
            strong: true; size: 40; iconSize: 16
            icon: ServiceMedia.playing ? Icon.mediaPause : Icon.mediaPlay
            onClicked: ServiceMedia.toggle()
        }
        LockButton
        {
            anchors.verticalCenter: parent.verticalCenter
            flat: true; size: 32; iconSize: 14
            icon: Icon.mediaNext
            enabled: ServiceMedia.player !== null && ServiceMedia.player.canGoNext
            onClicked: ServiceMedia.next()
        }
    }
}
