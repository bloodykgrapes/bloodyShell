import QtQuick
import Quickshell
import Quickshell.Wayland

import "../../common"
import "../../core"
import "../../services"
import "." as Parts

PanelWindow
{
    id: desktop

    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Parts.WallpaperLayer
    {
        anchors.fill: parent
        outputName: desktop.screen.name
    }

    MouseArea
    {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: mouse => OverlayState.showDesktopMenu(desktop.screen.name, mouse.x, mouse.y)
    }

    Equalizer
    {
        objectName: "desktopEqualizer"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.round(parent.height / 2)
        active: Config.desktopEqualizer
        visible: Config.desktopEqualizer
        opacity: Config.desktopEqualizerOpacity
        topColor: Theme.colorAccent
        bottomColor: topColor

        bars: 100

        minimumHeight: 0
    }
}
