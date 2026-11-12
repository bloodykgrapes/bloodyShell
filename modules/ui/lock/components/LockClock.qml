import QtQuick
import Quickshell

import "../../../core"

Column
{
    id: lockClock

    readonly property date now: clock.date
    SystemClock { id: clock; precision: SystemClock.Minutes }

    spacing: 0
    layer.enabled: true
    layer.effect: LockTextShadow {}

    Text
    {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: { const date = lockClock.now.toLocaleDateString(Tr.locale, "dddd, d MMMM"); return date.charAt(0).toUpperCase() + date.slice(1) }
        color: "#e2e2e7"
        font.family: Theme.fontText
        font.pixelSize: 16
        font.weight: Font.Medium
        font.letterSpacing: 0.5
    }
    Text
    {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: Qt.formatTime(lockClock.now, Config.barWidgetClock24 ? "HH:mm" : "h:mm")
        color: "#ffffff"
        font.family: Theme.fontText
        font.pixelSize: 104
        font.weight: Font.DemiBold
        font.letterSpacing: -4
    }
    Text
    {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !Config.barWidgetClock24
        text: Qt.formatTime(lockClock.now, "AP")
        color: "#e2e2e7"
        font.family: Theme.fontText
        font.pixelSize: 12
        font.letterSpacing: 2
    }
}
