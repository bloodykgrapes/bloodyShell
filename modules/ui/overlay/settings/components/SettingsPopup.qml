import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls

import "../../../../common"
import "../../../../core"

Controls.Popup
{
    id: popup

    required property Item host
    readonly property bool suspended: OverlayState.popupsSuspended
    property real reveal: 0
    property bool presenting: false
    property bool keyboardNavigation: false
    property Item focusOrigin: null

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
        function onAboutToShow()
        {
            popup.focusOrigin = popup.host.Window.window ? popup.host.Window.window.activeFocusItem : null;
            popup.keyboardNavigation = popup.focusOrigin?.visualFocus === true;
            popup.presenting = true;
        }
        function onAboutToHide()
        {
            const focused = popup.host.Window.window ? popup.host.Window.window.activeFocusItem : null;
            if (focused && focused.visualFocus !== undefined) popup.keyboardNavigation = focused.visualFocus;
        }
        function onClosed()
        {
            popup.presenting = false;
            restoreFocus.restart();
        }
    }

    Timer
    {
        id: restoreFocus
        interval: 0
        onTriggered:
        {
            const target = popup.focusOrigin;
            if (OverlayState.settingsPopup || popup.suspended || !popup.host?.visible || !target?.visible || !target.enabled) return;
            const reason = popup.keyboardNavigation ? Qt.TabFocusReason : Qt.MouseFocusReason;
            if (typeof target.focusFor === "function") target.focusFor(reason);
            else target.forceActiveFocus(reason);
        }
    }

    Controls.Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.4 * popup.reveal) }
    background: MenuReveal
    {
        objectName: "settingsPopupSurface"
        progress: 1
        color: Theme.settingsColorBackground
        borderWidth: 1
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
