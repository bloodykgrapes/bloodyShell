import QtQuick
import Quickshell
import Quickshell.Wayland

import "../components"
import "../core"
import "../services"

PanelWindow
{
    id: overlay

    signal hide()

    property bool shown: false
    property bool active: false

    property bool closeOnWorkspaceChange: true

    readonly property real reveal: fade.value

    readonly property real settle: Config.animationsFluid ? 1 - movement : 0

    property real movement: shown && active ? 1 : 0
    Spring on movement
    {
        duration: overlay.active ? Theme.animationDurationOpen : Theme.animationDurationClose
        curve: overlay.active && Config.animationsFluid ? [0.18, 1.35, 0.35, 1.0, 1.0, 1.0] : Theme.easingAccelerate
    }

    readonly property real lift: settle * 36

    color: "transparent"
    focusable: active
    exclusionMode: ExclusionMode.Ignore

    anchors
    {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Overlay

    ShortcutInhibitor
    {
        window: overlay
        enabled: overlay.active
    }
    Connections
    {
        target: ServiceCompositor
        enabled: overlay.active && overlay.closeOnWorkspaceChange
        function onFocusedWorkspaceIdChanged() { overlay.hide() }
    }

    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Component.onCompleted: Qt.callLater(() => overlay.shown = true)

    QtObject
    {
        id: fade

        property real value: overlay.shown && overlay.active ? 1 : 0

        Ease on value
        {
            duration: overlay.active ? Theme.animationDurationOpen : Theme.animationDurationClose
            curve: overlay.active ? Theme.easingEmphasized : Theme.easingAccelerate
        }
    }
    MouseArea
    {
        anchors.fill: parent
        enabled: fade.value > 0

        onClicked: overlay.hide()

        Rectangle
        {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.6 * fade.value
        }
    }
}
