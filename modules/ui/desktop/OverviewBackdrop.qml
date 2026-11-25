import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

import "../../services"

PanelWindow
{
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "bloodyShell:overview-backdrop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Item
    {
        anchors.fill: parent
        clip: true

        Image
        {
            id: image
            readonly property int blurRadius: 16

            // Render the blur at quarter resolution with room for the sampling edges.
            anchors.centerIn: parent
            width: Math.ceil(parent.width / scale) + 2 * blurRadius
            height: Math.ceil(parent.height / scale) + 2 * blurRadius
            scale: 4
            source: ServiceAppearance.fileUrl(ServiceAppearance.wallpaperImage)
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            retainWhileLoading: true
            layer.enabled: status === Image.Ready && GraphicsInfo.api !== GraphicsInfo.Software
            layer.textureSize: sourceSize
            layer.effect: MultiEffect
            {
                blurEnabled: true
                blurMax: image.blurRadius
                blur: 1
                autoPaddingEnabled: false
            }
        }

        Rectangle
        {
            anchors.fill: parent
            visible: image.status === Image.Ready
            color: "#52000000"
        }
    }
}
