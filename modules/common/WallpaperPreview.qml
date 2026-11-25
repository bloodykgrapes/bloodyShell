import QtQuick
import QtQuick.Effects
import "." as Common
import Quickshell.Widgets

import "../animations"
import "../core"

Common.InteractiveControl
{
    id: preview

    property string wallpaper: Config.wallpaperCurrent
    property real cornerRadius: Theme.radiusLarge
    property real hoverProgress: enabled && (hovered || visualFocus) ? 1 : 0
    signal clicked()

    implicitWidth: 344
    implicitHeight: 172
    activeFocusOnTab: true
    scale: area.pressed ? 0.98 : 1
    Spring on scale {}
    Ease on hoverProgress { duration: 320 }
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }

    ClippingRectangle
    {
        anchors.fill: parent
        radius: preview.cornerRadius
        color: Theme.colorField

        ShellIcon
        {
            anchors.centerIn: parent
            visible: picture.status !== Image.Ready
            icon: Icon.wallpapers
            size: 28
            opacity: 0.4 * (1 - preview.hoverProgress)
        }
        WallpaperImage
        {
            id: picture
            objectName: "wallpaperPreviewImage"
            anchors.fill: parent
            wallpaper: preview.wallpaper
            sourceSize: Qt.size(720, 360)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Smooth on opacity { duration: 300 }
            scale: 1 + 0.12 * preview.hoverProgress
            layer.enabled: preview.hoverProgress > 0 && status === Image.Ready
                && GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect
            {
                blurEnabled: true
                blurMax: 16
                blur: 0.75 * preview.hoverProgress
                autoPaddingEnabled: false
            }
        }
        Rectangle
        {
            anchors.fill: parent
            color: "#66000000"
            opacity: preview.hoverProgress
            visible: opacity > 0

            ShellText
            {
                anchors.centerIn: parent
                label: Tr.tr("settings.appearance.change")
                size: 16
                font.weight: Font.DemiBold
                color: "#ffffff"
            }
        }
    }
    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { preview.focusFor(Qt.MouseFocusReason); preview.clicked() }
    }

    Accessible.role: Accessible.Button
    Accessible.name: Tr.tr("common.wallpapers")
    Accessible.onPressAction: if (enabled) clicked()
}
