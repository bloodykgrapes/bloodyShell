import QtQuick
import QtQuick.Window

import "../../animations"
import "../../core"
import "../../services"
import "components"

FocusScope
{
    id: lock
    focus: true
    readonly property bool shown: visible && (!Window.window || Window.window.visible)
    readonly property bool keyboardOpened: prompt.keyboardOpened
    property real promptProgress: ServiceLock.promptVisible ? 1 : 0
    readonly property real promptReveal: Config.animationsEnabled ? promptProgress : ServiceLock.promptVisible ? 1 : 0
    Ease on promptProgress
    {
        enabled: Config.animationsEnabled && lock.shown
        duration: Config.animationsFluid ? 460 : 280
    }

    property real outro: ServiceLock.leaving ? 1 : 0
    Behavior on outro
    {
        enabled: Config.animationsEnabled && lock.shown
        NumberAnimation
        {
            duration: ServiceLock.unlockDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easingAccelerate
        }
    }
    readonly property real leave: Config.animationsEnabled ? outro : ServiceLock.leaving ? 1 : 0

    function showPrompt(text = "")
    {
        ServiceLock.showPrompt();
        if (!ServiceLock.promptVisible) return;
        prompt.focusInput();
        if (text) prompt.insertText(text);
    }

    function focusOverview()
    {
        if (shown && Window.window && !ServiceLock.promptVisible) forceActiveFocus();
    }

    Component.onCompleted: Qt.callLater(focusOverview)
    onVisibleChanged: if (visible) Qt.callLater(focusOverview)
    Connections
    {
        target: ServiceLock
        function onPromptVisibleChanged()
        {
            if (!ServiceLock.promptVisible)
            {
                ServiceVirtualKeyboard.hide();
                lock.focusOverview();
            }
        }
    }
    Keys.onPressed: event =>
    {
        if (ServiceLock.leaving || ServiceLock.preparingForSleep) { event.accepted = true; return; }
        if (!ServiceLock.promptVisible)
        {
            if (event.key === Qt.Key_Escape) { event.accepted = true; return; }
            if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta].includes(event.key)) return;
            const text = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter ? event.text : "";
            showPrompt(text);
        }
        else if (event.key === Qt.Key_Escape) ServiceLock.hidePrompt();
        else return;
        event.accepted = true;
    }

    LockBackdrop { anchors.fill: parent; leave: lock.leave; promptReveal: lock.promptReveal }
    LockOverview { anchors.fill: parent; dismiss: lock.promptReveal }
    MouseArea
    {
        objectName: "lockWakeArea"
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: !ServiceLock.leaving && !ServiceLock.preparingForSleep
        Accessible.ignored: ServiceLock.promptVisible
        Accessible.role: Accessible.Button
        Accessible.name: Tr.tr("lock.unlockHint")
        Accessible.onPressAction: lock.showPrompt()
        onClicked: lock.showPrompt()
    }
    LockPrompt { id: prompt; anchors.fill: parent; reveal: lock.promptReveal; leave: lock.leave }
}
