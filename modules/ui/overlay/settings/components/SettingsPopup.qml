import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls

import "../../../../core"

Controls.Popup
{
    id: popup

    required property Item host
    readonly property bool suspended: OverlayState.popupsSuspended
    property real reveal: 0
    property bool presenting: false

    parent:
    {
        let item = host;
        while (item && !item.popupLayer) item = item.parent;
        return item ? item.popupLayer : host.Window.window ? host.Window.window.contentItem : host;
    }
    popupType: Controls.Popup.Item
    modal: !suspended
    dim: !suspended
    focus: !suspended
    enabled: !suspended
    closePolicy: suspended ? Controls.Popup.NoAutoClose : Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    padding: 22
    transformOrigin: Item.Center
    opacity: suspended ? 0 : reveal
    scale: 1 - (Config.animationsFluid ? 0.06 : 0.02) * (1 - reveal)

    function syncModalState() { OverlayState.setPopupActive(popup, presenting && !suspended); }
    onPresentingChanged: syncModalState()
    onSuspendedChanged: syncModalState()
    Component.onDestruction: OverlayState.setPopupActive(popup, false)

    Connections
    {
        target: popup
        function onAboutToShow() { popup.presenting = true; }
        function onClosed() { popup.presenting = false; }
    }

    Controls.Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.4 * popup.reveal) }
    background: Rectangle
    {
        color: Theme.settingsColorCard
        radius: Theme.radiusLarge
        border.width: 1
        border.color: Theme.colorLine
    }
    enter: Transition
    {
        NumberAnimation
        {
            target: popup
            property: "reveal"
            to: 1
            duration: Config.animationsEnabled ? Theme.animationDurationControl : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easingEmphasized
        }
    }
    exit: Transition
    {
        NumberAnimation
        {
            target: popup
            property: "reveal"
            to: 0
            duration: Config.animationsEnabled ? Theme.animationDurationClose : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easingAccelerate
        }
    }
}
