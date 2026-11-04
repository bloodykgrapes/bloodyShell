import QtQuick

import ".."
import "../../core"

Rectangle
{
    id: settingsButton

    property string text: ""
    property string icon: ""
    property bool   danger: false

    signal clicked()

    width: content.implicitWidth + 30
    height: 32
    radius: Theme.radiusMedium
    opacity: enabled ? 1 : 0.4

    color: danger
        ? Qt.rgba(Theme.colorCritical.r, Theme.colorCritical.g, Theme.colorCritical.b, area.containsMouse ? 0.22 : 0.12)
        : area.pressed ? Theme.colorPressed : area.containsMouse ? Theme.colorHoverStrong : Theme.colorRaised
    border.width: 1
    border.color: Theme.colorHairline
    Tint on color {}

    scale: area.pressed ? 0.96 : area.containsMouse ? 1.03 : 1
    Spring on scale {}

    Row
    {
        id: content
        anchors.centerIn: parent
        spacing: 6

        ShellIcon
        {
            anchors.verticalCenter: parent.verticalCenter
            icon: settingsButton.icon
            size: 12
        }
        ShellText
        {
            anchors.verticalCenter: parent.verticalCenter
            label: settingsButton.text
            color: settingsButton.danger ? Theme.colorCritical : Theme.text1
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: settingsButton.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: settingsButton.clicked()
    }
}
