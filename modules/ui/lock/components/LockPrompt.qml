import QtQuick
import QtQuick.Window

import "../../../common"
import "../../../core"
import "../../../services"
import "../../keyboard"

Item
{
    id: prompt
    objectName: "lockPrompt"
    property real reveal: 0
    property real leave: 0
    readonly property string outputName: prompt.Window.window && prompt.Window.window.screen ? prompt.Window.window.screen.name : ""
    readonly property bool keyboardOpened: prompt.enabled && Config.virtualKeyboardEnabled && ServiceVirtualKeyboard.visible
        && ServiceVirtualKeyboard.output === outputName
    property real keyboardReveal: keyboardOpened ? 1 : 0
    Behavior on keyboardReveal { enabled: Config.animationsEnabled; NumberAnimation { duration: Theme.animationDurationControl; easing.type: Easing.OutCubic } }

    visible: reveal > 0 || ServiceLock.promptVisible
    opacity: reveal * (1 - leave)
    enabled: ServiceLock.promptVisible && !ServiceLock.leaving && !ServiceLock.preparingForSleep
    transform: Translate { y: 28 * (1 - prompt.reveal) - 18 * prompt.leave }

    function focusInput() { field.focusInput() }
    function insertText(text) { field.insertText(text) }

    Connections
    {
        target: ServiceLock
        function onFailuresChanged()
        {
            if (ServiceLock.failures === 0) return;
            field.clear();
            field.focusInput();
            if (Config.animationsEnabled) shake.restart();
        }
    }
    Connections
    {
        target: Config
        function onAnimationsEnabledChanged()
        {
            if (Config.animationsEnabled) return;
            shake.stop();
            unlockShift.x = 0;
        }
    }

    Item
    {
        id: contentArea
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top; margins: 28 }

        Column
        {
            objectName: "lockContent"
            anchors.centerIn: parent
            width: 380
            spacing: 28
            scale: Math.max(0.1, Math.min(1, contentArea.width / width, contentArea.height / implicitHeight))

            LockProfile { width: parent.width }
            LockPasswordField
            {
                id: field
                objectName: "lockPasswordField"
                transform: Translate { id: unlockShift }
                width: parent.width
                inputActive: prompt.enabled
                busy: ServiceLock.checking
                failed: ServiceLock.failed
                closed: ServiceLock.leaving || ServiceLock.preparingForSleep
                onSubmitted: password => ServiceLock.submit(password)
                onEdited: ServiceLock.failed = false
                onCancelled: ServiceLock.hidePrompt()
            }
        }
    }

    SequentialAnimation
    {
        id: shake
        NumberAnimation { target: unlockShift; property: "x"; to: -6; duration: Config.animationsFluid ? 75 : 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: unlockShift; property: "x"; to: 5; duration: Config.animationsFluid ? 70 : 50 }
        NumberAnimation { target: unlockShift; property: "x"; to: -3; duration: Config.animationsFluid ? 60 : 40 }
        NumberAnimation { target: unlockShift; property: "x"; to: 0; duration: Config.animationsFluid ? 65 : 40 }
    }

    Row
    {
        id: footer
        objectName: "lockFooter"
        anchors { right: parent.right; bottom: parent.bottom; margins: 28; bottomMargin: 28 + (keyboardContent.height + 20) * prompt.keyboardReveal }
        spacing: 8
        LockButton
        {
            objectName: "lockKeyboardButton"
            visible: Config.virtualKeyboardEnabled
            icon: Icon.keyboard; label: Tr.tr("keyboard.title")
            onClicked:
            {
                ServiceVirtualKeyboard.toggle(prompt.outputName);
                field.focusInput();
            }
        }
        LockButton { icon: Icon.computerSleep; label: Tr.tr("power.sleep"); onClicked: ServicePower.run("suspend") }
        LockButton { icon: Icon.computerReboot; label: Tr.tr("power.restart"); onClicked: ServicePower.run("reboot") }
        LockButton { icon: Icon.computerPowerOff; label: Tr.tr("power.shutDown"); onClicked: ServicePower.run("poweroff") }
    }

    Loader
    {
        id: keyboardContent
        active: Config.virtualKeyboardEnabled
        visible: prompt.keyboardReveal > 0.001
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(1, Math.min(840, prompt.width - 32))
        height: item ? item.implicitHeight : 0
        y: prompt.height - (height + 16) * prompt.keyboardReveal
        opacity: prompt.keyboardReveal
        sourceComponent: KeyboardContent { enabled: prompt.keyboardOpened && !ServiceLock.checking }
    }
}
