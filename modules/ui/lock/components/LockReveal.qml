import QtQuick

import "../../../animations"
import "../../../core"
import "../../../services"

Column
{
    id: lockReveal

    property int order: 0
    property bool ready: false
    property real progress: ready && visible ? 1 : 0
    readonly property real reveal: Config.animationsEnabled ? progress : 1
    readonly property real leave: Config.animationsEnabled ? exitProgress : ServiceLock.leaving ? 1 : 0
    property real exitProgress: ServiceLock.leaving ? 1 : 0

    width: parent ? parent.width : 0
    opacity: reveal * (1 - leave)
    scale: Config.animationsFluid ? 0.96 + 0.04 * reveal + 0.025 * leave : 1
    transform: Translate { y: Config.animationsEnabled ? (1 - lockReveal.reveal) * (Config.animationsFluid ? 26 : 10) - lockReveal.leave * 18 : 0 }

    Appear on progress
    {
        delay: Math.min(lockReveal.order, 5) * (Config.animationsFluid ? 55 : 24)
        duration: Config.animationsFluid ? 560 : 300
    }
    Behavior on exitProgress
    {
        enabled: Config.animationsEnabled
        NumberAnimation { duration: ServiceLock.unlockDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate }
    }

    Component.onCompleted: Qt.callLater(() => lockReveal.ready = true)
}
