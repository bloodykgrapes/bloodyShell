pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets

import "../../components"
import "../../components/bar"
import "../../core"
import "../../services"

Menu
{
    id: menuBattery

    implicitWidth: 300

    readonly property real  level: ServicePower.level
    readonly property color levelColor: ServicePower.percent <= 15 && !ServicePower.charging ? Theme.colorCritical
                                       : ServicePower.percent <= 30 && !ServicePower.charging ? Theme.colorWarning
                                       : Theme.colorAccent

    Item
    {
        width: parent.width
        height: 68

        ClippingRectangle
        {
            id: circle

            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            height: 56
            radius: width / 2
            color: Theme.colorField
            border.width: 1
            border.color: Theme.colorLine

            property real shown: Config.animationsFluid ? 0 : menuBattery.level
            Component.onCompleted: shown = Qt.binding(() => menuBattery.level)
            Ease on shown { duration: 900 }

            property real phase: 0
            FrameAnimation
            {
                running: Config.animationsEnabled && menuBattery.visible
                onTriggered: circle.phase += frameTime * (ServicePower.charging ? 3.2 : 1.4)
            }

            readonly property real surface: height * (1 - Math.max(0, Math.min(1, shown)))

            function wave(amp, length, shift)
            {
                const pts = [];
                const steps = 32;
                for (let i = 0; i <= steps; i++)
                {
                    const x = i / steps * width;
                    pts.push(Qt.point(x, surface + amp * Math.sin(x / length * Math.PI * 2 + phase + shift)));
                }
                pts.push(Qt.point(width, height + 2), Qt.point(0, height + 2));
                return pts;
            }

            Shape
            {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath
                {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: Qt.rgba(menuBattery.levelColor.r, menuBattery.levelColor.g, menuBattery.levelColor.b, 0.4)
                    PathPolyline { path: circle.wave(2.2, 42, 2.1 - circle.phase * 1.6) }
                }
                ShapePath
                {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: menuBattery.levelColor
                    PathPolyline { path: circle.wave(1.9, 54, 0) }
                }
            }

            Column
            {
                anchors.centerIn: parent
                spacing: 0

                ShellText
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    label: ServicePower.percent + "%"
                    size: 14
                    font.weight: Font.DemiBold
                    color: circle.shown > 0.55 ? Theme.colorSolid : Theme.text1
                    Tint on color { duration: 300 }
                }
                ShellIcon
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: ServicePower.charging
                    icon: Icon.battery
                    size: 9
                    opacity: 0.8
                }
            }
        }

        Column
        {
            anchors { left: circle.right; leftMargin: 12; right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 3

            ShellText
            {
                width: parent.width
                label: ServicePower.status
                color: Theme.text1
                size: 14
                font.weight: Font.Medium
            }
            ShellText
            {
                width: parent.width
                label: ServicePower.timeText !== "" ? (ServicePower.charging ? Tr.tr("menu.battery.untilFull") : Tr.tr("menu.battery.left")).arg(ServicePower.timeText) : ""
                color: Theme.text3
                size: 11
            }
            ShellText
            {
                width: parent.width
                label: ServicePower.infoPower
                color: Theme.text4
                size: 11
            }
        }
    }

    MenuSeparator { }

    MenuInfo { text: Tr.tr("common.capacity");  info: ServicePower.infoCapacity }

    MenuSeparator { }

    property int chosen: -1
    readonly property int profileShown: chosen >= 0 ? chosen : ServicePower.profileID
    Connections
    {
        target: ServicePower
        function onProfileIDChanged() { if (ServicePower.profileID === menuBattery.chosen) menuBattery.chosen = -1 }
    }
    Timer { id: settle; interval: 2000; onTriggered: menuBattery.chosen = -1 }

    Item
    {
        id: profiles

        readonly property var options: [
            { label: Tr.tr("menu.battery.saver"), icon: Icon.profileSaver },
            { label: Tr.tr("common.balanced"), icon: Icon.profileBalanced },
            { label: Tr.tr("common.performance"), icon: Icon.profilePerformance }
        ].slice(0, ServicePower.profileHasPerformance ? 3 : 2)

        readonly property real pad: 2
        readonly property real spacing: 2
        readonly property real segmentWidth: (width - pad * 2 - spacing * (options.length - 1)) / options.length

        width: parent.width
        height: 58

        Rectangle
        {
            anchors.fill: parent
            radius: Theme.radiusMedium
            color: Theme.menuColorHover
        }

        Rectangle
        {
            id: pill

            property bool settled: false
            Component.onCompleted: Qt.callLater(() => pill.settled = true)

            visible: menuBattery.profileShown >= 0
            x: profiles.pad + Math.max(0, menuBattery.profileShown) * (profiles.segmentWidth + profiles.spacing)
            y: profiles.pad
            width: profiles.segmentWidth
            height: profiles.height - profiles.pad * 2
            radius: Theme.radiusSmall
            color: Theme.colorChosen

            Glide on x { enabled: Config.animationsEnabled && pill.settled }
        }

        Repeater
        {
            model: profiles.options

            Rectangle
            {
                id: segment

                required property var modelData
                required property int index
                readonly property bool current: menuBattery.profileShown === index

                x: profiles.pad + index * (profiles.segmentWidth + profiles.spacing)
                y: profiles.pad
                width: profiles.segmentWidth
                height: profiles.height - profiles.pad * 2
                radius: Theme.radiusSmall
                color: !current && area.containsMouse ? Theme.colorHover : "transparent"
                Tint on color {}

                scale: area.pressed ? 0.97 : 1
                Behavior on scale
                {
                    enabled: Config.animationsEnabled
                    NumberAnimation { duration: 130; easing.type: Easing.OutBack }
                }

                Column
                {
                    anchors.centerIn: parent
                    spacing: 5

                    ShellIcon
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: segment.modelData.icon
                        size: 18
                        opacity: segment.current ? 1 : 0.6
                        Smooth on opacity {}
                    }
                    ShellText
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        label: segment.modelData.label
                        size: 11
                        color: segment.current ? Theme.text1 : Theme.text3
                        Tint on color {}
                    }
                }

                MouseArea
                {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked:
                    {
                        if (segment.current) return;
                        menuBattery.chosen = segment.index;
                        settle.restart();
                        ServicePower.setProfile(segment.index);
                    }
                }

                Accessible.role: Accessible.RadioButton
                Accessible.name: segment.modelData.label
                Accessible.checked: segment.current
            }
        }
    }
}
