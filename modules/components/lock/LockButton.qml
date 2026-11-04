import QtQuick

import ".."
import "../../core"

Rectangle
{
    id: lockButton

    property string icon: ""
    property int    size: 40
    property int    iconSize: Math.round(size * 0.42)
    property bool   strong: false
    property bool   flat: false
    signal clicked()

    width: size
    height: size
    color: "transparent"
    radius: hit.containsMouse ? Math.round(size * 0.3) : size / 2
    Behavior on radius { enabled: Config.animationsEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    scale: hit.pressed ? 0.9 : hit.containsMouse ? 1.08 : 1
    Spring on scale {}

    LockShadow { visible: glass.opacity > 0; opacity: glass.opacity }

    LockGlass
    {
        id: glass
        anchors.fill: parent
        radius: parent.radius
        hovered: hit.containsMouse || hit.pressed
        opacity: !lockButton.flat || hit.containsMouse ? 1 : 0
        Behavior on opacity { enabled: Config.animationsEnabled; NumberAnimation { duration: 160 } }
    }

    Rectangle
    {
        anchors.fill: parent
        radius: parent.radius
        color: hit.pressed ? Theme.lockPressed : hit.containsMouse ? Theme.lockHover : lockButton.strong ? Theme.lockStrong : "transparent"
        Tint on color {}
    }

    Image
    {
        anchors.centerIn: parent
        source: lockButton.icon
        width: lockButton.iconSize
        height: width
        sourceSize: Qt.size(width * 2, width * 2)
        opacity: lockButton.enabled ? 1 : 0.3
    }

    MouseArea
    {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        enabled: lockButton.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: lockButton.clicked()
    }
}
