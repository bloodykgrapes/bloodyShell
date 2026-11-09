import QtQuick
import Quickshell.Widgets

import "../../../common"
import "../../../core"
import "../../../services"

Item
{
    id: lockMedia

    height: 132

    RenderActivity { id: activity; target: lockMedia }
    readonly property bool positionWanted: activity.active && ServiceMedia.length > 0
    onPositionWantedChanged: ServiceMedia.setPositionActive(lockMedia, positionWanted)
    Component.onCompleted: ServiceMedia.setPositionActive(lockMedia, positionWanted)
    Component.onDestruction: ServiceMedia.setPositionActive(lockMedia, false)

    LockShadow { target: surface }
    LockSurface { id: surface; anchors.fill: parent; radius: 22 }

    ClippingRectangle
    {
        id: cover
        x: 16; y: 16
        width: 58; height: 58
        radius: 14
        color: Theme.lockStrong

        Image { anchors.centerIn: parent; visible: art.status !== Image.Ready; source: Icon.music; width: 24; height: 24; sourceSize: Qt.size(48, 48) }
        Image
        {
            id: art
            anchors.fill: parent
            source: ServiceMedia.art
            sourceSize: Qt.size(116, 116)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column
    {
        anchors { left: cover.right; leftMargin: 14; right: parent.right; rightMargin: 16; verticalCenter: cover.verticalCenter }
        spacing: 4
        ShellText { width: parent.width; label: ServiceMedia.title || ServiceMedia.app; size: 15; color: Theme.lockText1; font.weight: Font.DemiBold }
        ShellText { width: parent.width; label: ServiceMedia.artist || ServiceMedia.album; size: 12; color: Theme.lockText2 }
    }

    Rectangle
    {
        x: 16; y: 88
        width: parent.width - 32; height: 1
        color: Theme.lockSurfaceEdge
    }

    ShellText
    {
        anchors { left: parent.left; leftMargin: 18; verticalCenter: controls.verticalCenter; right: controls.left; rightMargin: 12 }
        label: ServiceMedia.time(ServiceMedia.position) + "  /  " + ServiceMedia.time(ServiceMedia.length)
        size: 11
        color: Theme.lockText3
        visible: ServiceMedia.length > 0
    }

    Row
    {
        id: controls
        anchors { right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 6 }
        spacing: 6

        LockButton
        {
            anchors.verticalCenter: parent.verticalCenter
            flat: true; size: 30; iconSize: 14
            icon: Icon.mediaPrevious
            label: Tr.tr("menu.media.previousTrack")
            enabled: ServiceMedia.player !== null && ServiceMedia.player.canGoPrevious
            onClicked: ServiceMedia.previous()
        }
        LockButton
        {
            anchors.verticalCenter: parent.verticalCenter
            strong: true; size: 34; iconSize: 15
            icon: ServiceMedia.playing ? Icon.mediaPause : Icon.mediaPlay
            label: ServiceMedia.playing ? Tr.tr("menu.media.pause") : Tr.tr("menu.media.play")
            enabled: ServiceMedia.player !== null && ServiceMedia.player.canTogglePlaying
            onClicked: ServiceMedia.toggle()
        }
        LockButton
        {
            anchors.verticalCenter: parent.verticalCenter
            flat: true; size: 30; iconSize: 14
            icon: Icon.mediaNext
            label: Tr.tr("menu.media.nextTrack")
            enabled: ServiceMedia.player !== null && ServiceMedia.player.canGoNext
            onClicked: ServiceMedia.next()
        }
    }
}
