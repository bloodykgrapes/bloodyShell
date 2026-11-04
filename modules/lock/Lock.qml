import QtQuick
import Quickshell.Widgets

import "../components"
import "../components/lock"
import "../core"
import "../services"

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

    readonly property Item glassSource: backdrop.image
    readonly property bool moving: intro < 1 || (outro > 0 && outro < 1) || shake.running

    LockBackdrop { id: backdrop; anchors.fill: parent; appear: lock.introBack; leave: lock.outro }

    MouseArea { anchors.fill: parent; onClicked: field.focusInput() }

    LockClock
    {
        id: clock
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Math.round(parent.height * 0.1) }
        opacity: lock.introTop * lock.shown
        transform: Translate { y: (1 - lock.introTop) * -lock.rise - lock.outro * 20 }
    }

    Column
    {
        id: unlock

        anchors { horizontalCenter: parent.horizontalCenter; top: clock.bottom; topMargin: Math.round(parent.height * 0.07) }
        width: Math.round(360 * Config.themeScale)
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
                width: Math.round(104 * Config.themeScale)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Theme.lockGlassEdge

                LockGlass { anchors.fill: parent; radius: avatar.radius; edge: false }
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

        Item
        {
            readonly property int gap: 26

            visible: (Config.lockMediaPlayer && ServiceMedia.available) || (Config.lockNotifications && ServiceNotifications.count > 0)
            width: parent.width
            height: gap + extras.height

            Rectangle
            {
                y: parent.gap
                width: parent.width
                height: extras.height
                radius: 22
                color: "transparent"
                LockShadow {}
                LockGlass { anchors.fill: parent; radius: parent.radius }
            }

            Column
            {
                id: extras

                y: parent.gap
                width: parent.width
                padding: 16
                spacing: 20

                layer.enabled: true
                layer.effect: LockTextShadow { soft: true }

                LockMedia { visible: Config.lockMediaPlayer && ServiceMedia.available; width: extras.width - extras.leftPadding - extras.rightPadding }
                LockNotifications { visible: Config.lockNotifications && count > 0; width: extras.width - extras.leftPadding - extras.rightPadding }
            }
        }
    }

    Row
    {
        anchors { right: parent.right; bottom: parent.bottom; margins: Math.round(28 * Config.themeScale) }
        spacing: 8
        opacity: lock.introFoot * lock.shown
        transform: Translate { y: (1 - lock.introFoot) * lock.rise + lock.outro * 16 }

        LockButton { icon: Icon.computerSleep;    onClicked: ServicePower.run("suspend") }
        LockButton { icon: Icon.computerReboot;   onClicked: ServicePower.run("reboot") }
        LockButton { icon: Icon.computerPowerOff; onClicked: ServicePower.run("poweroff") }
    }
}
