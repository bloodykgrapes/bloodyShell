import QtQuick

import ".."
import "../../core"

Rectangle
{
    id: settingsIconButton

    property string icon: ""
    property int    iconSize: 12
    property bool   autoRepeat: false

    signal clicked()

    width: 28
    height: 28
    radius: Theme.radiusMedium
    opacity: enabled ? 1 : 0.3

    color: area.pressed ? Theme.colorPressed : area.containsMouse ? Theme.colorHover : Theme.colorField
    Tint on color {}

    scale: area.pressed ? 0.92 : area.containsMouse && enabled ? 1.08 : 1
    Spring on scale {}

    ShellIcon
    {
        anchors.centerIn: parent
        icon: settingsIconButton.icon
        size: settingsIconButton.iconSize
        zoom: 1.1
    }

    property bool repeated: false
    Timer
    {
        id: repeater
        interval: 380
        repeat: true
        running: area.pressed && settingsIconButton.autoRepeat && settingsIconButton.enabled
        onTriggered:
        {
            settingsIconButton.repeated = true;
            interval = 70;
            settingsIconButton.clicked();
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: settingsIconButton.enabled
        cursorShape: Qt.PointingHandCursor
        onPressedChanged: if (pressed) { settingsIconButton.repeated = false; repeater.interval = 380 }
        onClicked: if (!settingsIconButton.repeated) settingsIconButton.clicked()
    }
}
