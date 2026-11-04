pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell.Services.Mpris
import Quickshell.Widgets

import "../../components"
import "../../components/bar"
import "../../core"
import "../../services"
import "../../src/Visualizer.js" as Visualizer

Menu
{
    id: menuMedia

    implicitWidth: 320

    RenderActivity
    {
        id: activity
        target: menuMedia
    }

    readonly property bool visualizerWanted: activity.active && Config.animationsEnabled
    readonly property bool positionWanted: activity.active && ServiceMedia.length > 0
    onVisualizerWantedChanged: ServiceMedia.setVisualizerActive(menuMedia, visualizerWanted)
    onPositionWantedChanged: ServiceMedia.setPositionActive(menuMedia, positionWanted)
    Component.onCompleted:
    {
        ServiceMedia.setVisualizerActive(menuMedia, visualizerWanted);
        ServiceMedia.setPositionActive(menuMedia, positionWanted);
    }
    Component.onDestruction:
    {
        ServiceMedia.setVisualizerActive(menuMedia, false);
        ServiceMedia.setPositionActive(menuMedia, false);
    }

    ClippingRectangle
    {
        id: spectrum

        parent: menuMedia
        z: -1
        anchors.fill: parent
        anchors.bottomMargin: 9
        radius: 9
        color: "transparent"

        readonly property bool live: menuMedia.visualizerWanted && ServiceMedia.levels.length > 0
        opacity: live ? 1 : 0
        Smooth on opacity { duration: 500 }
        visible: opacity > 0

        Equalizer
        {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            radius: 1
            height: Math.round(parent.height * 0.6)
            barWidth: 6

            active: menuMedia.visualizerWanted
        }
    }

    Item
    {
        width: parent.width
        height: 100

        Shape
        {
            id: blob

            readonly property real size: 116
            width: size
            height: size
            x: cover.x + cover.width / 2 - size / 2
            y: cover.y + cover.height / 2 - size / 2
            preferredRendererType: Shape.CurveRenderer

            readonly property real bass:
            {
                if (!menuMedia.visualizerWanted) return 0;
                const l = ServiceMedia.levels;
                if (l.length === 0) return 0;
                let sum = 0;
                for (let i = 0; i < 6; i++) sum += l[i] || 0;
                return sum / 6;
            }
            property real energy: bass
            Behavior on energy { enabled: menuMedia.visualizerWanted; NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

            property real phase: 0
            readonly property bool live: menuMedia.visualizerWanted && ServiceMedia.levels.length > 0
            opacity: live ? 1 : 0
            Smooth on opacity { duration: 500 }
            visible: opacity > 0

            FrameAnimation
            {
                running: blob.visible && menuMedia.visualizerWanted
                onTriggered: blob.phase += frameTime * (0.6 + blob.energy * 1.6)
            }

            readonly property var points: Visualizer.points(size / 2, cover.width / 2 + 8 + energy * 14, 2.5 + energy * 8, phase)

            ShapePath
            {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Theme.accentShell ? Theme.accentAlpha(0.4) : Theme.inkAlpha(0.16)
                PathPolyline { path: blob.points }
            }
        }

        ClippingRectangle
        {
            id: cover

            x: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            height: 64
            radius: Theme.radiusLarge
            color: Theme.colorField

            scale: coverMouse.pressed ? 0.94
                 : coverMouse.containsMouse ? 1.08 : 1

            Spring on scale {}

            ShellIcon
            {
                anchors.centerIn: parent
                visible: front.status !== Image.Ready && back.status !== Image.Ready
                icon: Icon.music
                size: 24
                opacity: 0.6
            }

            Image
            {
                id: back
                anchors.fill: parent
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Image
            {
                id: front
                anchors.fill: parent
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0
                scale: Config.animationsFluid ? 1.08 - 0.08 * opacity : 1

                onStatusChanged: if (status === Image.Ready) reveal.restart()
            }
            NumberAnimation
            {
                id: reveal
                target: front; property: "opacity"; from: 0; to: 1
                duration: Config.animationsEnabled ? 360 : 0
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized
            }

            function show(url)
            {
                if (url === String(front.source)) return;
                back.source = front.opacity > 0.5 ? front.source : back.source;
                reveal.stop();
                front.opacity = 0;
                front.source = url;
                if (url === "") back.source = "";
            }
            Component.onCompleted: show(ServiceMedia.art)
            Connections { target: ServiceMedia; function onArtChanged() { cover.show(ServiceMedia.art) } }

            MouseArea
            {
                id: coverMouse

                anchors.fill: parent
                z: 10

                hoverEnabled: true

                enabled: ServiceMedia.player !== null

                cursorShape: enabled
                    ? Qt.PointingHandCursor
                    : Qt.ArrowCursor

                onClicked:
                {
                    ServiceWindowActions.activateMediaPlayer(ServiceMedia.player);
                    MenuState.close();
                }
            }
        }

        Column
        {
            id: info

            anchors.left: cover.right
            anchors.leftMargin: 26
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            property real shift: 0
            transform: Translate { x: info.shift }

            Connections
            {
                target: ServiceMedia
                function onTitleChanged() { if (activity.active && Config.animationsEnabled) trackChange.restart() }
            }
            ParallelAnimation
            {
                id: trackChange
                NumberAnimation { target: info; property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
                NumberAnimation { target: info; property: "shift"; from: 10; to: 0; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
            }

            ShellText
            {
                width: parent.width
                label: ServiceMedia.title
                size: 14
                color: Theme.text1
                font.weight: Font.DemiBold
            }
            ShellText
            {
                width: parent.width
                label: ServiceMedia.artist
                size: 12
                color: Theme.text2
            }
            ShellText
            {
                width: parent.width
                label: ServiceMedia.album
                size: 11
                color: Theme.text3
            }
        }
    }

    Item
    {
        visible: ServiceMedia.length > 0
        width: parent.width
        height: 34

        Item
        {
            id: track

            x: 6
            y: 4
            width: parent.width - 12
            height: 14

            property real basePosition: ServiceMedia.position
            property real baseTime: Date.now()
            property real now: Date.now()
            readonly property real position: ServiceMedia.playing
                ? Math.min(ServiceMedia.length, basePosition + Math.max(0, now - baseTime) / 1000)
                : basePosition

            Connections
            {
                target: ServiceMedia
                function onPositionChanged() { track.basePosition = ServiceMedia.position; track.baseTime = Date.now(); track.now = track.baseTime }
                function onPlayingChanged() { track.basePosition = ServiceMedia.position; track.baseTime = Date.now(); track.now = track.baseTime }
            }
            Timer
            {
                interval: Math.max(16, Math.min(100, Math.round(ServiceMedia.length * 1000 / Math.max(1, track.width))))
                repeat: true
                running: ServiceMedia.playing && menuMedia.positionWanted && Config.animationsEnabled
                onTriggered: track.now = Date.now()
            }

            readonly property real shown: seek.pressed ? seek.dragPos
                : ServiceMedia.length > 0 ? Math.min(1, position / ServiceMedia.length) : 0

            Rectangle
            {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: seek.containsMouse || seek.pressed ? 6 : 4
                radius: height / 2
                color: Theme.colorField
                Glide on height {}

                Rectangle
                {
                    width: Math.max(parent.height, parent.width * track.shown)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.colorAccent
                }

                Rectangle
                {
                    x: Math.max(0, parent.width * track.shown - width / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: 6
                    color: Theme.colorAccent
                    scale: seek.pressed ? 1.15 : seek.containsMouse ? 1 : 0
                    Spring on scale {}
                }
            }

            MouseArea
            {
                id: seek

                property real dragPos: 0

                anchors.fill: parent
                anchors.margins: -6
                enabled: ServiceMedia.canSeek
                hoverEnabled: true
                cursorShape: ServiceMedia.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                preventStealing: true

                function at(mx) { return Math.max(0, Math.min(1, (mx - 6) / track.width)) }

                onPressed: mouse => dragPos = at(mouse.x)
                onPositionChanged: mouse => { if (pressed) dragPos = at(mouse.x) }

                onReleased: ServiceMedia.seekTo(dragPos)
            }
        }

        ShellText
        {
            x: 6
            anchors.bottom: parent.bottom
            label: ServiceMedia.time(seek.pressed ? seek.dragPos * ServiceMedia.length : track.position)
            size: 10
            color: Theme.text3
            font.family: Theme.fontMono
        }
        ShellText
        {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.bottom: parent.bottom
            label: ServiceMedia.time(ServiceMedia.length)
            size: 10
            color: Theme.text3
            font.family: Theme.fontMono
        }
    }

    Item
    {
        width: parent.width
        height: 60

        Control
        {
            anchors.verticalCenter: parent.verticalCenter
            x: 6
            visible: ServiceMedia.player !== null && ServiceMedia.player.shuffleSupported
            icon: Icon.mediaShuffle
            size: 34
            on: ServiceMedia.player !== null && ServiceMedia.player.shuffle
            label: Tr.tr("menu.media.shuffle")
            onClicked: ServiceMedia.toggleShuffle()
        }

        Row
        {
            anchors.centerIn: parent
            spacing: 10

            Control
            {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icon.mediaPrevious
                enabled: ServiceMedia.player !== null && ServiceMedia.player.canGoPrevious
                label: Tr.tr("menu.media.previousTrack")
                onClicked: ServiceMedia.previous()
            }
            Control
            {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icon.mediaPlay
                altIcon: Icon.mediaPause
                alt: ServiceMedia.playing
                size: 48
                iconSize: 20
                primary: true
                enabled: ServiceMedia.player !== null && ServiceMedia.player.canTogglePlaying
                label: ServiceMedia.playing ? Tr.tr("menu.media.pause") : Tr.tr("menu.media.play")
                onClicked: ServiceMedia.toggle()
            }
            Control
            {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icon.mediaNext
                enabled: ServiceMedia.player !== null && ServiceMedia.player.canGoNext
                label: Tr.tr("menu.media.nextTrack")
                onClicked: ServiceMedia.next()
            }
        }

        Control
        {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 6
            visible: ServiceMedia.player !== null && ServiceMedia.player.loopSupported
            icon: Icon.mediaRepeat
            size: 34
            on: ServiceMedia.player !== null && ServiceMedia.player.loopState !== MprisLoopState.None
            dot: ServiceMedia.player !== null && ServiceMedia.player.loopState === MprisLoopState.Track
            label: Tr.tr("menu.media.repeat")
            onClicked: ServiceMedia.cycleLoop()
        }
    }

    Repeater
    {
        model: ServiceMedia.players.length > 1 ? ServiceMedia.players : []

        MenuRow
        {
            required property var modelData

            icon: Icon.music
            text: modelData.identity || modelData.dbusName
            subtitle: modelData.trackTitle || ""
            selected: modelData === ServiceMedia.player
            onClicked: ServiceMedia.choose(modelData)
        }
    }

    MenuLabel { hint: true; text: Tr.tr("common.nothingIsPlaying"); visible: !ServiceMedia.available }

    component Control: Rectangle
    {
        id: control

        property string icon: ""
        property string altIcon: ""
        property bool   alt: false
        property string label: ""
        property int    size: 40
        property int    iconSize: 16
        property bool   primary: false
        property bool   on: false
        property bool   dot: false

        signal clicked()

        width: size
        height: size
        radius: size / 2
        opacity: enabled ? 1 : 0.35

        color: area.pressed ? Theme.colorPressed
             : primary ? (area.containsMouse ? Qt.tint(Theme.colorSelection, Theme.inkAlpha(0.1)) : Theme.colorSelection)
             : on ? Theme.colorSelection
             : area.containsMouse ? Theme.colorHover : "transparent"
        Tint on color {}

        scale: area.pressed ? 0.92 : area.containsMouse ? 1.06 : 1
        Spring on scale {}

        Item
        {
            anchors.centerIn: parent
            width: control.iconSize
            height: control.iconSize
            opacity: control.on || control.primary || area.containsMouse ? 1 : 0.75

            property real morph: control.alt ? 1 : 0
            Ease on morph { duration: Theme.animationDurationControl }

            ShellIcon
            {
                anchors.centerIn: parent
                icon: control.icon
                size: control.iconSize
                opacity: 1 - parent.morph
                scale: 1 - 0.4 * parent.morph
                rotation: -90 * parent.morph
            }
            ShellIcon
            {
                anchors.centerIn: parent
                visible: control.altIcon !== ""
                icon: control.altIcon
                size: control.iconSize
                opacity: parent.morph
                scale: 0.6 + 0.4 * parent.morph
                rotation: 90 * (1 - parent.morph)
            }
        }
        Rectangle
        {
            visible: control.dot
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: 4; height: 4; radius: 2
            color: Theme.text1
        }

        MouseArea
        {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: control.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }

        Accessible.role: Accessible.Button
        Accessible.name: control.label
    }
}
