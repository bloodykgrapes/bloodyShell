import QtQuick
import Quickshell
import Quickshell.Wayland

import "../../common"
import "../../core"

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

    MouseArea
    {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: mouse => OverlayState.showDesktopMenu(desktop.screen.name, mouse.x, mouse.y)
    }

    Equalizer
    {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.round(parent.height / 2)
        active: Config.desktopEqualizer
        visible: Config.desktopEqualizer

        bars: 100

        minimumHeight: 0
    }
}
