import QtQuick

import "../../animations"
import "../../animations/OverlayMotion.js" as Motion
import "../../core"

FocusScope
{
    id: view

    required property var host
    property string name: ""
    property Item scrimCutout: null

    readonly property bool active: host.activeFor(name)
    readonly property real reveal: Math.min(host.revealFor(name), arrival)

    property bool ready: false
    property real arrival: ready ? 1 : 0
    Ease on arrival
    {
        duration: Config.animationsFluid ? Motion.openDuration(view.name) : Theme.animationDurationOpen
        curve: Config.animationsFluid ? Motion.openCurve(view.name) : Theme.easingEmphasized
    }
    Component.onCompleted: ready = true

    function hide() { host.dismiss(name) }
    Keys.onEscapePressed: hide()
}
