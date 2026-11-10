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
    readonly property real introBack: Config.animationsEnabled ? intro : 1

    NumberAnimation
    {
        id: introAnim
        target: lock; property: "intro"; from: 0; to: 1
        duration: Config.animationsFluid ? 800 : 360
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized
    }
    Component.onCompleted: if (Config.animationsEnabled) introAnim.start()

    property real outro: ServiceLock.leaving ? 1 : 0
    Behavior on outro { enabled: Config.animationsEnabled; NumberAnimation { duration: ServiceLock.unlockDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate } }
    readonly property real leave: Config.animationsEnabled ? outro : ServiceLock.leaving ? 1 : 0

    LockBackdrop { anchors.fill: parent; appear: lock.introBack; leave: lock.leave }

    Connections
    {
        target: Config
        function onAnimationsEnabledChanged()
        {
            if (Config.animationsEnabled) return;
            introAnim.stop();
            lock.intro = 1;
            shake.stop();
            unlockShift.x = 0;
        }
    }

    MouseArea { anchors.fill: parent; onClicked: field.focusInput() }

    Item
    {
        id: contentArea
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top; margins: 28 }
        enabled: !ServiceLock.leaving && !ServiceLock.preparingForSleep

        Column
        {
            id: content
            objectName: "lockContent"
            anchors.centerIn: parent
            width: Math.round(380 * Config.themeScale)
            spacing: 28
            scale: Math.max(0.1, Math.min(1, contentArea.width / width, contentArea.height / implicitHeight))

            LockReveal
            {
                objectName: "lockClockReveal"
                LockClock { width: parent.width }
            }

            Column
            {
                id: unlock

                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                spacing: 14

                SequentialAnimation
                {
                    id: shake
                    NumberAnimation { target: unlockShift; property: "x"; to: -6; duration: Config.animationsFluid ? 75 : 50; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: unlockShift; property: "x"; to: 5;  duration: Config.animationsFluid ? 70 : 50 }
                    NumberAnimation { target: unlockShift; property: "x"; to: -3; duration: Config.animationsFluid ? 60 : 40 }
                    NumberAnimation { target: unlockShift; property: "x"; to: 0;  duration: Config.animationsFluid ? 65 : 40 }
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

                LockReveal
                {
                    order: 1
                    spacing: 14

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
                }

                LockReveal
                {
                    objectName: "lockPasswordReveal"
                    order: 2

                    LockPasswordField
                    {
                        id: field
                        transform: Translate { id: unlockShift }
                        width: parent.width
                        busy: ServiceLock.checking
                        failed: ServiceLock.failed
                        closed: ServiceLock.leaving || ServiceLock.preparingForSleep
                        onSubmitted: password => ServiceLock.submit(password)
                        onEdited: ServiceLock.failed = false
                    }
                }

                Column
                {
                    width: parent.width
                    spacing: 12
                    visible: ServiceMedia.available || (Config.lockNotifications && ServiceNotifications.count > 0)

                    LockReveal
                    {
                        order: 3
                        visible: ServiceMedia.available
                        LockMedia { width: parent.width }
                    }
                    LockReveal
                    {
                        order: 4
                        visible: Config.lockNotifications && notifications.count > 0
                        LockNotifications { id: notifications; width: parent.width }
                    }
                }
            }
        }
    }

    LockReveal
    {
        id: footer
        objectName: "lockFooter"
        anchors { right: parent.right; bottom: parent.bottom; margins: Math.round(28 * Config.themeScale) }
        width: actions.implicitWidth
        order: 5
        enabled: !ServiceLock.leaving && !ServiceLock.preparingForSleep

        Row
        {
            id: actions
            spacing: 8

            LockButton { icon: Icon.computerSleep;    label: Tr.tr("power.sleep"); onClicked: ServicePower.run("suspend") }
            LockButton { icon: Icon.computerReboot;   label: Tr.tr("power.restart"); onClicked: ServicePower.run("reboot") }
            LockButton { icon: Icon.computerPowerOff; label: Tr.tr("power.shutDown"); onClicked: ServicePower.run("poweroff") }
        }
    }
}
