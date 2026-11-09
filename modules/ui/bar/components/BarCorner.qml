import QtQuick

import "../../../animations"
import "../../../common"
import "../../../core"

MouseArea
{
    id: corner

    required property string side
    required property var screen
    property bool hinted: false
    width: Theme.sidebarCorner
    height: Theme.barThickness
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: side === "left" ? Tr.tr("sidebar.left") : Tr.tr("sidebar.right")
    Accessible.onPressAction: toggle()

    function toggle() { if (screen) SidebarState.toggle(side, screen.name) }
    onClicked: toggle()

    ShellIcon
    {
        anchors.centerIn: parent
        icon: corner.side === "left" ? Icon.chevronRight : Icon.chevronLeft
        size: 14
        opacity: corner.containsMouse || corner.hinted || (SidebarState.current === corner.side && SidebarState.onOutput(corner.screen ? corner.screen.name : "")) ? 1 : 0
        transform: Translate { x: corner.containsMouse || corner.hinted ? 0 : corner.side === "left" ? -5 : 5; Glide on x { duration: 200 } }
        Smooth on opacity { duration: 160 }
    }
}
