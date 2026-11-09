import QtQuick

import "../../animations"
import "../../core"

FocusScope
{
    required property var host
    property string name: ""

    readonly property bool active: host.activeFor(name)
    readonly property real reveal: host.revealFor(name) * arrival
    readonly property real settle: Config.animationsFluid ? 1 - reveal : 0
    readonly property real lift: settle * 36

    property bool ready: false
    property real arrival: ready ? 1 : 0
    Ease on arrival { duration: Theme.animationDurationOpen }
    Component.onCompleted: Qt.callLater(() => ready = true)

    function hide() { host.dismiss(name) }
    Keys.onEscapePressed: hide()
}
