pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"

Menu
{
    id: menuMedia

    implicitWidth: 360
    centerOnWidget: true
    spacing: 10

    function focusControl(item)
    {
        if (MenuState.menuActive)
        {
            for (let owner = menuMedia; owner; owner = owner.parent)
            {
                if (owner !== MenuState.menuOwner) continue;
                MenuState.menuKeyboard = true;
                break;
            }
        }
        item.forceActiveFocus(Qt.MouseFocusReason);
    }

    readonly property bool visualizerWanted: menuMedia.active && Config.animationsEnabled
    readonly property bool positionWanted: menuMedia.active && ServiceMedia.length > 0
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

    RevealSection
    {
        shown: menuMedia.presented
        order: 0

        ClippingRectangle
        {
            width: parent.width
            height: Math.max(112, info.implicitHeight + 32)
            radius: Theme.radiusLarge
            color: Theme.colorField

            Equalizer
            {
                anchors.fill: parent
                anchors.topMargin: parent.height * 0.45
                active: menuMedia.visualizerWanted
                opacity: menuMedia.visualizerWanted && ServiceMedia.levels.length > 0 ? 0.45 : 0
                Smooth on opacity { duration: 200 }
                barWidth: 5
                radius: 2
            }

            ClippingRectangle
            {
                id: cover
                objectName: "mediaArtwork"

                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 80
                height: 80
                radius: Theme.radiusMedium
                color: Theme.colorField

                scale: coverMouse.pressed ? 0.98
                     : coverMouse.containsMouse ? 1.025 : 1

                Smooth on scale { duration: 240 }

                property bool showingA: true
                property string requested: ""
                property real blend: 0
                readonly property Image currentImage: showingA ? artA : artB
                readonly property Image incomingImage: showingA ? artB : artA
                readonly property bool incomingReady: incomingImage.status === Image.Ready

                function show(url)
                {
                    requested = String(url || "");
                    if (!reveal.running) loadRequested();
                }
                function loadRequested()
                {
                    if (reveal.running) return;
                    if (requested === String(currentImage.source) && (requested === "" || currentImage.status === Image.Ready))
                    {
                        incomingImage.source = "";
                        return;
                    }
                    incomingImage.source = requested;
                    if (requested === "" || incomingImage.status === Image.Ready || incomingImage.status === Image.Error)
                        beginReveal();
                }
                function loaded(image)
                {
                    if (image === incomingImage && !reveal.running && String(image.source) === requested
                        && (image.status === Image.Ready || image.status === Image.Error)) beginReveal();
                }
                function beginReveal()
                {
                    if (reveal.running) return;
                    if (Config.animationsEnabled && menuMedia.active) reveal.start();
                    else finishReveal();
                }
                function finishReveal()
                {
                    showingA = !showingA;
                    blend = 0;
                    incomingImage.source = "";
                    if (requested !== String(currentImage.source)) Qt.callLater(loadRequested);
                }

                Component.onCompleted: show(ServiceMedia.art)
                Connections { target: ServiceMedia; function onArtChanged() { cover.show(ServiceMedia.art) } }
                Connections
                {
                    target: Config
                    function onAnimationsEnabledChanged() { if (!Config.animationsEnabled && reveal.running) reveal.complete() }
                }

                ShellIcon
                {
                    anchors.centerIn: parent
                    opacity: cover.currentImage.status === Image.Ready
                        ? (cover.incomingReady ? 0 : cover.blend)
                        : (cover.incomingReady ? 1 - cover.blend : 1)
                    icon: Icon.music
                    size: 24
                }

                Image
                {
                    id: artA
                    anchors.fill: parent
                    sourceSize: Qt.size(160, 160)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    z: cover.showingA ? 0 : 1
                    opacity: cover.showingA ? (cover.incomingReady ? 1 : 1 - cover.blend) : cover.blend
                    scale: Config.animationsFluid && !cover.showingA ? 1.025 - 0.025 * cover.blend : 1
                    onStatusChanged: cover.loaded(artA)
                }
                Image
                {
                    id: artB
                    anchors.fill: parent
                    sourceSize: Qt.size(160, 160)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    z: cover.showingA ? 1 : 0
                    opacity: cover.showingA ? cover.blend : (cover.incomingReady ? 1 : 1 - cover.blend)
                    scale: Config.animationsFluid && cover.showingA ? 1.025 - 0.025 * cover.blend : 1
                    onStatusChanged: cover.loaded(artB)
                }
                NumberAnimation
                {
                    id: reveal
                    target: cover; property: "blend"; from: 0; to: 1
                    duration: Config.animationsFluid ? 520 : 400
                    easing.type: Easing.InOutCubic
                    onFinished: cover.finishReveal()
                }

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
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                property real shift: 0
                transform: Translate { x: info.shift }

                Connections
                {
                    target: ServiceMedia
                    function onTitleChanged() { if (menuMedia.active && Config.animationsEnabled) trackChange.restart() }
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
                    label: ServiceMedia.app
                    size: 10
                    color: Theme.text3
                    font.weight: Font.Medium
                }
                ShellText
                {
                    width: parent.width
                    label: ServiceMedia.title
                    size: 15
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
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
    }

    RevealSection
    {
        shown: menuMedia.presented
        order: 1

        Item
        {
            visible: ServiceMedia.length > 0
            width: parent.width
            height: 40

            Item
            {
                id: track
                objectName: "mediaSeek"
                enabled: ServiceMedia.canSeek
                activeFocusOnTab: enabled
                Accessible.role: Accessible.Slider
                Accessible.name: Tr.tr("menu.media.seek")
                Accessible.onIncreaseAction: seekBy(5)
                Accessible.onDecreaseAction: seekBy(-5)
                function seekBy(seconds)
                {
                    if (ServiceMedia.canSeek)
                        ServiceMedia.seekTo(Math.max(0, Math.min(1, (position + seconds) / ServiceMedia.length)));
                }
                Keys.onLeftPressed: seekBy(-5)
                Keys.onRightPressed: seekBy(5)
                Keys.onPressed: event =>
                {
                    if (event.key === Qt.Key_Home) { ServiceMedia.seekTo(0); event.accepted = true; }
                    else if (event.key === Qt.Key_End) { ServiceMedia.seekTo(1); event.accepted = true; }
                }

                x: 6
                y: 2
                width: parent.width - 12
                height: 24

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
                    : ServiceMedia.length > 0 ? Math.max(0, Math.min(1, position / ServiceMedia.length)) : 0

                Rectangle
                {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seek.containsMouse || seek.pressed || track.activeFocus ? 6 : 4
                    radius: height / 2
                    color: Theme.colorField
                    Glide on height {}

                    Rectangle
                    {
                        width: parent.width * track.shown
                        height: parent.height
                        radius: parent.radius
                        color: Theme.colorAccent
                    }

                    Rectangle
                    {
                        x: Math.max(0, Math.min(parent.width - width, parent.width * track.shown - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.colorAccent
                        scale: seek.pressed ? 1.15 : seek.containsMouse || track.activeFocus ? 1 : 0
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

                    onPressed: mouse => { menuMedia.focusControl(track); dragPos = at(mouse.x) }
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
    }

    RevealSection
    {
        shown: menuMedia.presented
        order: 2

        Item
        {
            width: parent.width
            height: 64

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
                spacing: 8

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
                    objectName: "mediaPlayPause"
                    size: 56
                    iconSize: 24
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
    }

    RevealSection
    {
        shown: menuMedia.presented
        order: 3

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

        MenuLabel { hint: true; text: Tr.tr("common.noMedia"); visible: !ServiceMedia.available }
    }

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
        radius: primary ? Theme.radiusLarge : size / 2
        activeFocusOnTab: enabled
        border.width: activeFocus ? 2 : 0
        border.color: Theme.colorAccent
        Keys.onSpacePressed: clicked()
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
        opacity: enabled ? 1 : 0.35

        color: area.pressed ? Theme.colorPressed
             : primary ? (area.containsMouse ? Qt.tint(Theme.colorSelection, Theme.inkAlpha(0.1)) : Theme.colorSelection)
             : on ? Theme.colorSelection
             : area.containsMouse ? Theme.colorHover : Theme.colorField
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
            onClicked: { menuMedia.focusControl(control); control.clicked() }
        }

        Accessible.role: Accessible.Button
        Accessible.name: control.label
        Accessible.onPressAction: clicked()
    }
}
