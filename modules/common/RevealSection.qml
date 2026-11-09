import QtQuick

import "../animations"
import "../core"

Column
{
    id: section

    property bool shown: true
    property int order: 0
    property bool ready: false
    property real reveal: shown && ready && visible ? 1 : 0

    width: parent ? parent.width : 0
    spacing: 2
    opacity: reveal
    scale: Config.animationsFluid ? 0.97 + 0.03 * reveal : 1
    transform: Translate { y: Config.animationsEnabled ? 12 * (1 - section.reveal) : 0 }
    Appear on reveal { delay: Config.animationsFluid ? 35 + Math.min(section.order, 6) * 30 : Math.min(section.order, 6) * 12 }

    Component.onCompleted: Qt.callLater(() => section.ready = true)
}
