import QtQuick
import Quickshell.Widgets

import "../../components"
import "../../components/bar"
import "../../core"
import "../../services"

Widget
{
    id: widgetMedia
    menu: Registry.widgets.media.menu

    active: ServiceMedia.available

    readonly property string label: ServiceMedia.artist !== "" && ServiceMedia.title !== ""
        ? ServiceMedia.artist + "  ·  " + ServiceMedia.title
        : ServiceMedia.title
    readonly property real labelMax: Math.round(220 * Config.themeScale)

    MouseArea
    {
        id: button

        readonly property real padding: Math.round(7 * Config.themeScale)
        readonly property real coverSize: Math.round(18 * Config.themeScale)

        implicitHeight: Theme.barWidgetHeight
        implicitWidth: widgetMedia.vertical ? Math.max(implicitHeight, coverSize + 6)
                                       : Math.ceil(padding + coverSize + 7 + caption.width + padding)

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        scale: pressed ? 0.94 : containsMouse ? 1.06 : 1
        Spring on scale {}

        opacity: ServiceMedia.playing ? 1 : 0.6
        Smooth on opacity {}

        onClicked: mouse => mouse.button === Qt.MiddleButton ? ServiceMedia.toggle() : widgetMedia.toggleMenu()
        onWheel: wheel =>
        {
            const steps = widgetMedia.wheelSteps(wheel);
            if (steps > 0) ServiceMedia.previous();
            else if (steps < 0) ServiceMedia.next();
        }

        Rectangle
        {
            anchors.fill: parent
            radius: Math.min(Theme.barWidgetRadius, height / 2)
            color: button.pressed || widgetMedia.menuOpen ? Theme.colorPressed
                 : button.containsMouse ? Theme.colorHover : "transparent"
            Tint on color {}
        }

        Equalizer
        {
            anchors
            {
                fill: parent
                leftMargin: 5
                rightMargin: 5
                bottomMargin: 2
            }
            
            radius: 1
            minimumHeight: 1
            barWidth: 5

            topColor: Theme.accentShell ? Theme.accentAlpha(0.10) : Theme.inkAlpha(0.06)
            bottomColor: Theme.accentShell ? Theme.accentAlpha(0.35) : Theme.inkAlpha(0.20)
        }

        ClippingRectangle
        {
            id: cover

            x: widgetMedia.vertical ? Math.round((parent.width - width) / 2) : button.padding
            anchors.verticalCenter: parent.verticalCenter
            width: button.coverSize
            height: button.coverSize
            radius: Math.round(5 * Config.themeScale)
            color: "transparent"

            ShellIcon
            {
                anchors.centerIn: parent
                icon: Icon.music
                size: 16
                opacity: art.ready ? 0 : 1
                Smooth on opacity { duration: 220 }
            }
            Image
            {
                id: art
                readonly property bool ready: status === Image.Ready && String(source) !== ""
                anchors.fill: parent
                source: ServiceMedia.art
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: ready ? 1 : 0
                Smooth on opacity { duration: 220 }
            }
        }

        Item
        {
            id: caption

            visible: !widgetMedia.vertical
            anchors { left: cover.right; leftMargin: 7; verticalCenter: parent.verticalCenter }
            width: Math.min(full.implicitWidth, widgetMedia.labelMax)
            height: full.implicitHeight
            clip: overflow > 0

            readonly property real overflow: Math.max(0, full.implicitWidth - widgetMedia.labelMax)
            readonly property bool scrolling: overflow > 0 && button.containsMouse && Config.animationsEnabled

            Text
            {
                id: full

                style: Theme.onGlass(full) ? Text.Outline : Text.Normal
                styleColor: Theme.foregroundShadow

                text: widgetMedia.label
                color: button.containsMouse || widgetMedia.menuOpen ? Theme.text1 : Theme.text2
                font.pixelSize: Math.round(12 * Config.themeScale)
                font.family: Theme.fontText

                width: caption.scrolling || marquee.running ? implicitWidth : caption.width
                elide: caption.scrolling || marquee.running ? Text.ElideNone : Text.ElideRight
                Tint on color {}
            }

            SequentialAnimation
            {
                id: marquee

                running: caption.scrolling
                loops: Animation.Infinite

                PauseAnimation { duration: 700 }
                NumberAnimation { target: full; property: "x"; to: -caption.overflow; duration: caption.overflow * 28; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 1100 }
                NumberAnimation { target: full; property: "x"; to: 0; duration: caption.overflow * 28; easing.type: Easing.InOutSine }

                onRunningChanged: if (!running) back.restart()
            }

            NumberAnimation { id: back; target: full; property: "x"; to: 0; duration: 260; easing.type: Easing.OutCubic }
        }
    }
}
