import QtQuick
import Quickshell.Widgets

import "../animations"
import "../core"

Item
{
    id: preview

    property string wallpaper: Config.wallpaperCurrent
    signal clicked()
    RenderActivity { id: activity; target: preview }

    implicitWidth: 344
    implicitHeight: 172
    activeFocusOnTab: true
    scale: area.pressed ? 0.98 : 1
    Spring on scale {}
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }

    ClippingRectangle
    {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Theme.colorField

        ShellIcon
        {
            anchors.centerIn: parent
            visible: picture.status !== Image.Ready
            icon: Icon.wallpapers
            size: 28
            opacity: 0.4
        }
        Image
        {
            id: picture
            objectName: "wallpaperPreviewImage"
            anchors.fill: parent
            source: activity.active && preview.wallpaper !== "" ? "file://" + String(preview.wallpaper).replace(/^file:\/\//, "") : ""
            sourceSize: Qt.size(720, 360)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Smooth on opacity { duration: 300 }
            scale: area.containsMouse || preview.activeFocus ? 1.04 : 1
            Ease on scale { duration: 500 }
        }
        Rectangle
        {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 60
            gradient: Gradient
            {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.7) }
            }
        }
        ShellText
        {
            anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 10; right: change.left; rightMargin: 10 }
            label: preview.wallpaper !== "" ? preview.wallpaper.substring(preview.wallpaper.lastIndexOf("/") + 1) : Tr.tr("settings.appearance.noWallpaper")
            textFormat: Text.PlainText
            size: 12
            color: "#ffffff"
        }
        Rectangle
        {
            id: change
            anchors { right: parent.right; rightMargin: 10; bottom: parent.bottom; bottomMargin: 8 }
            width: caption.implicitWidth + 22
            height: 26
            radius: 13
            color: Qt.rgba(1, 1, 1, area.containsMouse || preview.activeFocus ? 0.28 : 0.16)
            Tint on color {}
            ShellText { id: caption; anchors.centerIn: parent; label: Tr.tr("settings.appearance.change"); size: 11; color: "#ffffff" }
        }
    }
    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { preview.forceActiveFocus(Qt.MouseFocusReason); preview.clicked() }
    }

    Accessible.role: Accessible.Button
    Accessible.name: Tr.tr("common.wallpapers")
    Accessible.onPressAction: if (enabled) clicked()
}
