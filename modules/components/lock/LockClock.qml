import QtQuick
import Quickshell

import "../../core"

Column
{
    id: lockClock

    readonly property date now: clock.date
    SystemClock { id: clock; precision: SystemClock.Minutes }

    spacing: 4

    layer.enabled: true
    layer.effect: LockTextShadow {}

    Text
    {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(lockClock.now, Config.barWidgetClock24 ? "HH:mm" : "h:mm")
        color: "#ffffff"
        font.family: Theme.fontText
        font.pixelSize: Math.round(96 * Config.themeScale)
        font.weight: Font.Bold
    }
    Text
    {
        anchors.horizontalCenter: parent.horizontalCenter
        text: { const s = lockClock.now.toLocaleDateString(Tr.locale, "dddd, d MMMM"); return s.charAt(0).toUpperCase() + s.slice(1) }
        color: "#ffffff"
        font.family: Theme.fontText
        font.pixelSize: Math.round(18 * Config.themeScale)
    }
}
