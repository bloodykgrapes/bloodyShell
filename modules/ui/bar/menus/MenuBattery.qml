pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets

import "../../../src/Visualizer.js" as Visualizer
import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"

Menu
{
    id: menuBattery

    implicitWidth: 320

    readonly property real level: Math.max(0, Math.min(1, ServicePower.level))
    readonly property color levelColor: ServicePower.percent <= 15 && !ServicePower.charging ? Theme.colorCritical
        : ServicePower.percent <= 30 && !ServicePower.charging ? Theme.colorWarning : Theme.colorAccent
    readonly property string estimate: ServicePower.timeText !== ""
        ? (ServicePower.charging ? Tr.tr("menu.battery.untilFull") : Tr.tr("menu.battery.left")).arg(ServicePower.timeText) : ""

    RevealSection
    {
        shown: menuBattery.presented
        order: 0

        Rectangle
        {
            visible: ServicePower.present
            width: parent.width
            height: Math.max(104, summary.implicitHeight + 24)
            radius: Theme.radiusLarge
            color: Theme.colorCurrent

            Accessible.role: Accessible.StaticText
            Accessible.name: ServicePower.percent + "%, " + ServicePower.status + (menuBattery.estimate !== "" ? ", " + menuBattery.estimate : "")

            ClippingRectangle
            {
                id: circle

                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                width: 64
                height: 64
                radius: width / 2
                color: Theme.colorField

                property real shown: Config.animationsFluid ? 0 : menuBattery.level
                Component.onCompleted: shown = Qt.binding(() => menuBattery.level)
                Ease on shown { duration: 900 }

                property real phase: 0
                readonly property real surface: height * (1 - shown)
                readonly property real amplitude: Math.sin(Math.PI * shown)
                readonly property bool animating: menuBattery.active && ServicePower.present && Config.animationsEnabled && shown > 0 && shown < 1

                FrameAnimation
                {
                    running: circle.animating
                    onTriggered: circle.phase = (circle.phase + Math.min(frameTime, 0.05) * (ServicePower.charging ? 3.2 : 1.4)) % (Math.PI * 10)
                }

                readonly property var frontBasis: Visualizer.waveBasis(width, 62)
                readonly property var backBasis: Visualizer.waveBasis(width, 48)

                Shape
                {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath
                    {
                        strokeWidth: 0
                        strokeColor: "transparent"
                        fillColor: Qt.rgba(menuBattery.levelColor.r, menuBattery.levelColor.g, menuBattery.levelColor.b, 0.4)
                        PathPolyline { path: Visualizer.wave(circle.backBasis, circle.height, circle.surface, 2.6 * circle.amplitude, 2.1 - circle.phase * 0.6) }
                    }
                    ShapePath
                    {
                        strokeWidth: 0
                        strokeColor: "transparent"
                        fillColor: menuBattery.levelColor
                        PathPolyline { path: Visualizer.wave(circle.frontBasis, circle.height, circle.surface, 2.2 * circle.amplitude, circle.phase) }
                    }
                }

                Rectangle
                {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    color: Theme.colorSolid

                    ShellIcon { anchors.centerIn: parent; icon: Icon.battery; size: 18 }
                }
            }

            Column
            {
                id: summary
                anchors { left: circle.right; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 3

                ShellText
                {
                    width: parent.width
                    label: ServicePower.percent + "%"
                    size: 28
                    font.weight: Font.DemiBold
                    color: Theme.text1
                }
                ShellText
                {
                    width: parent.width
                    label: ServicePower.status
                    size: 12
                    color: Theme.text2
                    wrapMode: Text.Wrap
                }
                ShellText
                {
                    width: parent.width
                    label: menuBattery.estimate
                    size: 11
                    color: Theme.text3
                    wrapMode: Text.Wrap
                }
            }
        }

        MenuLabel { hint: true; visible: !ServicePower.present; text: Tr.tr("menu.battery.noBattery") }
    }

    RevealSection
    {
        shown: menuBattery.presented
        order: 1

        MenuLabel { visible: ServicePower.present; text: Tr.tr("menu.battery.details") }
        MenuInfo { visible: ServicePower.present && ServicePower.infoPower !== ""; text: Tr.tr("common.power"); info: ServicePower.infoPower }
        MenuInfo { visible: ServicePower.present && ServicePower.infoCapacity !== ""; text: Tr.tr("common.capacity"); info: ServicePower.infoCapacity }
        MenuInfo { visible: ServicePower.present && ServicePower.healthPercent >= 0; text: Tr.tr("settings.power.health"); info: ServicePower.healthPercent + "%" }
    }

    RevealSection
    {
        shown: menuBattery.presented
        order: 2

        MenuSeparator {}
        MenuLabel { text: Tr.tr("settings.power.powerMode") }

        Repeater
        {
            model: [
                { value: 0, label: Tr.tr("menu.battery.saver"), hint: Tr.tr("menu.battery.saverHint"), icon: Icon.profileSaver },
                { value: 1, label: Tr.tr("common.balanced"), hint: Tr.tr("menu.battery.balancedHint"), icon: Icon.profileBalanced },
                { value: 2, label: Tr.tr("common.performance"), hint: Tr.tr("menu.battery.performanceHint"), icon: Icon.profilePerformance }
            ].slice(0, ServicePower.profileHasPerformance ? 3 : 2)

            MenuRow
            {
                required property var modelData

                icon: modelData.icon
                text: modelData.label
                subtitle: modelData.hint
                selected: ServicePower.profileID === modelData.value
                activeFocusOnTab: true
                onClicked: if (!selected) ServicePower.setProfile(modelData.value)

                Keys.onSpacePressed: clicked()
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()

                Accessible.role: Accessible.RadioButton
                Accessible.checkable: true
                Accessible.checked: selected
            }
        }
    }

    RevealSection
    {
        shown: menuBattery.presented
        order: 3

        MenuSeparator {}
        MenuItem
        {
            icon: Icon.settingsPower
            text: Tr.tr("menu.battery.settings")
            onClicked:
            {
                const index = Registry.settings.findIndex(page => page.id === "power");
                if (index < 0) return;
                OverlayState.settingsPage = index;
                OverlayState.show("settings");
            }
        }
    }
}
