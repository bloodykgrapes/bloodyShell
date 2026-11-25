import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls

import "../../../../animations/OverlayMotion.js" as Motion
import "../../../../core"
import "../.." as OverlayUI

Controls.Popup
{
    id: popup

    required property Item host
    property Item panelContent: null
    readonly property bool suspended: OverlayState.popupsSuspended
    readonly property bool revealPanel: Config.animationsFluid || ShellMaterial.backdrop
    property real reveal: 0
    property bool presenting: false
    property bool keyboardNavigation: false
    property Item focusOrigin: null
    property real preferredWidth: 460
    property real preferredHeight: 0

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
    padding: 0
    width: Math.min(preferredWidth, Math.max(0, parent.width - 32))
    height: Math.min(preferredHeight > 0 ? preferredHeight : implicitHeight, Math.max(0, parent.height - 32))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    opacity: suspended ? 0 : panelContent ? Motion.panelOpacity(reveal, revealPanel) : 1
    scale: panelContent && !revealPanel ? 0.98 + 0.02 * reveal : 1

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
    background: null
    contentItem: OverlayUI.OverlayPanel
    {
        objectName: "settingsPopupSurface"
        reveal: popup.revealPanel ? popup.reveal : 1
        surfaceColor: Theme.popupColorBackground
        useSurfaceMaterial: !ShellMaterial.blur
        radius: Theme.popupRadius
        implicitWidth: (popup.panelContent?.implicitWidth ?? 0) + 2 * Theme.popupPadding
        implicitHeight: (popup.panelContent?.implicitHeight ?? 0) + 2 * Theme.popupPadding

        Item
        {
            id: bodyHost
            anchors.fill: parent
            anchors.margins: Theme.popupPadding
        }
    }
    Binding
    {
        target: popup.panelContent
        property: "parent"
        value: bodyHost
        when: popup.panelContent !== null
    }
    enter: Transition
    {
        NumberAnimation
        {
            target: popup
            property: "reveal"
            to: 1
            duration: !Config.animationsEnabled ? 0
                : Config.animationsFluid ? Motion.fluidOpenDuration : Theme.animationDurationControl
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.animationsFluid ? Motion.fluidOpenCurve : Theme.easingEmphasized
        }
    }
    exit: Transition
    {
        NumberAnimation
        {
            target: popup
            property: "reveal"
            to: 0
            duration: Config.animationsEnabled ? OverlayState.closeDuration : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.animationsFluid ? Motion.fluidCloseCurve : Theme.easingAccelerate
        }
    }
}
