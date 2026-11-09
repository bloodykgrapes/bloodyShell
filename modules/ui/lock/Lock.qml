import QtQuick
import Quickshell.Widgets

import "../../common"
import "../../core"
import "../../services"
import "components"

Item
{
    id: lock

    property real intro: Config.animationsEnabled ? 0 : 1
    function phase(from, length) { return Math.max(0, Math.min(1, (intro - from) / length)) }
    readonly property real introBack: phase(0.0, 0.7)
    readonly property real introTop:  phase(0.1, 0.55)
    readonly property real introMain: phase(0.22, 0.55)
    readonly property real introFoot: phase(0.38, 0.55)

    readonly property real rise: Config.animationsFluid ? 26 : 12

    NumberAnimation
    {
        id: introAnim
        target: lock; property: "intro"; from: 0; to: 1
        duration: Config.animationsFluid ? 1100 : 700
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized
    }
    Component.onCompleted: if (Config.animationsEnabled) introAnim.start()

    property real outro: ServiceLock.leaving ? 1 : 0
    Behavior on outro { enabled: Config.animationsEnabled; NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate } }
    readonly property real shown: 1 - outro

    LockBackdrop { anchors.fill: parent; appear: lock.introBack; leave: lock.outro }

    MouseArea { anchors.fill: parent; onClicked: field.focusInput() }

    Item
    {
        id: contentArea
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top; margins: 28 }

        Column
        {
            id: content
            objectName: "lockContent"
            anchors.centerIn: parent
            width: Math.round(380 * Config.themeScale)
            spacing: 28
            scale: Math.max(0.1, Math.min(1, contentArea.width / width, contentArea.height / implicitHeight))

            LockClock
            {
                id: clock
                width: parent.width
                opacity: lock.introTop * lock.shown
                transform: Translate { y: (1 - lock.introTop) * -lock.rise - lock.outro * 20 }
            }

            Column
            {
                id: unlock

                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                spacing: 14

                opacity: lock.introMain * lock.shown
                scale: 1 - 0.04 * lock.outro
                transform: Translate { id: unlockShift; y: (1 - lock.introMain) * lock.rise }

                SequentialAnimation
                {
                    id: shake
                    NumberAnimation { target: unlockShift; property: "x"; to: -6; duration: 50; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: unlockShift; property: "x"; to: 5;  duration: 50 }
                    NumberAnimation { target: unlockShift; property: "x"; to: -3; duration: 40 }
                    NumberAnimation { target: unlockShift; property: "x"; to: 0;  duration: 40 }
                }
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

                Item
                {
                    width: parent.width
                    height: avatar.height

                    LockShadow { target: avatar }

                    ClippingRectangle
                    {
                        id: avatar
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(88 * Config.themeScale)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.lockSurfaceEdge

                        LockSurface { anchors.fill: parent; radius: avatar.radius; edge: false }
                        Image
                        {
                            anchors.centerIn: parent
                            visible: face.status !== Image.Ready
                            source: Icon.user
                            width: Math.round(avatar.width * 0.42)
                            height: width
                            sourceSize: Qt.size(width * 2, height * 2)
                        }
                        Image
                        {
                            id: face
                            anchors.fill: parent
                            source: ServiceUser.avatar !== "" ? "file://" + ServiceUser.avatar : ""
                            sourceSize: Qt.size(208, 208)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                    }
                }

                ShellText
                {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    label: ServiceUser.fullName !== "" ? ServiceUser.fullName : ServiceUser.user
                    size: 20
                    color: Theme.lockText1
                    font.weight: Font.DemiBold
                    layer.enabled: true
                    layer.effect: LockTextShadow {}
                }

                LockPasswordField
                {
                    id: field
                    width: parent.width
                    busy: ServiceLock.checking
                    failed: ServiceLock.failed
                    closed: ServiceLock.leaving
                    onSubmitted: password => ServiceLock.submit(password)
                    onEdited: ServiceLock.failed = false
                }

                Column
                {
                    width: parent.width
                    spacing: 12
                    visible: (Config.lockMediaPlayer && ServiceMedia.available) || (Config.lockNotifications && ServiceNotifications.count > 0)

                    LockMedia { visible: Config.lockMediaPlayer && ServiceMedia.available; width: parent.width }
                    LockNotifications { visible: Config.lockNotifications && count > 0; width: parent.width }
                }
            }
        }
    }

    Row
    {
        id: footer
        objectName: "lockFooter"
        anchors { right: parent.right; bottom: parent.bottom; margins: Math.round(28 * Config.themeScale) }
        spacing: 8
        opacity: lock.introFoot * lock.shown
        transform: Translate { y: (1 - lock.introFoot) * lock.rise + lock.outro * 16 }

        LockButton { icon: Icon.computerSleep;    label: Tr.tr("power.sleep"); onClicked: ServicePower.run("suspend") }
        LockButton { icon: Icon.computerReboot;   label: Tr.tr("power.restart"); onClicked: ServicePower.run("reboot") }
        LockButton { icon: Icon.computerPowerOff; label: Tr.tr("power.shutDown"); onClicked: ServicePower.run("poweroff") }
    }
}
