pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"
import "../components"

Widget
{
    id: island
    objectName: "dynamicIsland"

    menu: Qt.resolvedUrl("../menus/MenuIsland.qml")
    active: !ServiceLock.locked
    implicitWidth: faceWidth
    implicitHeight: faceHeight

    readonly property Item host:
    {
        for (let item = parent; item; item = item.parent)
            if (item.islandOutput !== undefined) return item;
        return null;
    }
    readonly property string output: host?.islandOutput ?? ""
    readonly property var presentation: ServiceIsland.view(output)
    readonly property bool eventWanted: presentation.kind === "osd" || presentation.kind === "notification"
    readonly property bool playing: active && ServiceIsland.mediaActive && !ServiceCompositor.fullscreenOnOutput(output)
    readonly property bool capturing: active && (ServiceIsland.recordingActive || ServiceIsland.cameraActive)
    readonly property bool hoveringFace: hit.containsMouse
    property bool hoverConsumed: false
    onHoveringFaceChanged: if (!hoveringFace) hoverConsumed = false
    readonly property real limit: Math.max(32, Math.min(320, (host?.centerLimit ?? 320) - Theme.barPadding * 2))
    readonly property real verticalWidth: Math.max(48, Math.min(260, (QsWindow.window?.width ?? 400) - 48))
    readonly property string timeText: Qt.formatDateTime(clock.date, (Config.barWidgetClock24 ? "HH" : "hh")
        + ":mm" + (Config.barWidgetClockSeconds ? ":ss" : "") + (Config.barWidgetClock24 ? "" : " AP"))
    readonly property string fullDate: Qt.formatDateTime(clock.date, "ddd d MMM")
    readonly property string compactDate: Qt.formatDateTime(clock.date, "d MMM")
    readonly property string inlineClock: timeText + "  ·  " + fullDate
    readonly property real clockWidth: Math.max(140, Math.ceil(clockMetrics.advanceWidth) + 24)
    readonly property bool stackedClock: vertical || limit < clockWidth + (playing ? 62 : 0)
    readonly property real homeWidth: vertical ? 36 : Math.min(limit, clockWidth + (playing ? 62 : 0))
    readonly property real homeHeight: vertical ? (playing ? 90 : 46) : stackedClock ? 38 : 32

    property var event: ({kind: "", title: "", subtitle: "", value: -1})
    readonly property bool notification: event.kind === "notification"
    readonly property real eventWidth: Math.min(vertical ? verticalWidth : limit, Math.max(vertical ? 112 : homeWidth,
        Math.max(eventTitleMetrics.advanceWidth, eventDetailMetrics.advanceWidth) + (notification ? 80 : 58)))
    property real heldEventWidth: 0
    readonly property real eventHeight: Math.max(vertical ? homeHeight : 32, eventText.implicitHeight + (notification ? 18 : 12))

    property real faceWidth: Math.max(homeWidth, eventWanted ? Math.min(eventWidthLimit, heldEventWidth) : 0)
    property real faceHeight: Math.max(homeHeight, eventWanted ? eventHeight : 0)
    readonly property real eventWidthLimit: vertical ? verticalWidth : limit
    property real eventReveal: eventWanted ? 1 : 0
    property real mediaReveal: playing ? 1 : 0
    property real captureReveal: capturing ? 1 : 0
    Glide on faceWidth { duration: Theme.animationDurationBar }
    Glide on faceHeight { duration: Theme.animationDurationBar }
    Glide on eventReveal { duration: Theme.animationDuration(220) }
    Smooth on mediaReveal { duration: Theme.animationDuration(180) }
    Smooth on captureReveal { duration: Theme.animationDuration(180) }

    function syncEvent()
    {
        if (eventWanted)
        {
            event = presentation;
            heldEventWidth = Math.max(heldEventWidth, eventWidth);
        }
        else heldEventWidth = 0;
    }
    onEventWantedChanged: syncEvent()
    onPresentationChanged: syncEvent()
    onEventWidthChanged: if (eventWanted) heldEventWidth = Math.max(heldEventWidth, eventWidth)
    onEventRevealChanged: if (eventReveal <= 0 && !eventWanted) event = ({kind: "", title: "", subtitle: "", value: -1})

    function openMenu()
    {
        if (menuOpen) return;
        hoverConsumed = hoveringFace;
        MenuState.islandTab = "controls";
        MenuState.toggle(menu, island);
    }

    function toggleMenu()
    {
        if (menuOpen) MenuState.close();
        else openMenu();
    }

    onMenuOpenChanged: ServiceIsland.setMediaMenu(island, menuOpen)
    Component.onDestruction: ServiceIsland.setMediaMenu(island, false)

    SystemClock { id: clock; precision: Config.barWidgetClockSeconds ? SystemClock.Seconds : SystemClock.Minutes }
    TextMetrics
    {
        id: clockMetrics
        text: island.inlineClock.replace(/\d/g, "0")
        font.family: Theme.fontText
        font.pixelSize: 12
        font.features: ({tnum: 1})
    }
    TextMetrics { id: eventTitleMetrics; text: island.event.title || ""; font: eventTitle.font }
    TextMetrics { id: eventDetailMetrics; text: island.event.subtitle || ""; font: eventDetail.font }

    MouseArea
    {
        id: hit
        objectName: "islandCompactContent"

        width: island.width
        height: island.height
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: island.eventWanted ? island.event.title || Tr.tr("shell.dynamicIsland")
            : island.timeText + ", " + island.fullDate
        Accessible.onPressAction: island.toggleMenu()

        Keys.onReturnPressed: event => { if (!event.isAutoRepeat) island.toggleMenu(); }
        Keys.onSpacePressed: event => { if (!event.isAutoRepeat) island.toggleMenu(); }
        onClicked: mouse =>
        {
            if (mouse.button === Qt.MiddleButton && island.playing && !island.eventWanted) ServiceMedia.toggle();
            else if (mouse.button === Qt.LeftButton) island.toggleMenu();
        }
        onWheel: wheel =>
        {
            wheel.accepted = island.playing && !island.eventWanted;
            if (!wheel.accepted) return;
            const steps = island.wheelSteps(wheel);
            if (steps > 0) ServiceMedia.previous();
            else if (steps < 0) ServiceMedia.next();
        }

        Timer
        {
            interval: Config.barHoverDelay
            running: Config.barHoverExpand && hit.containsMouse && !island.hoverConsumed && !island.menuOpen && island.active
            onTriggered: island.openMenu()
        }

        Item
        {
            id: face
            anchors.fill: parent
            scale: hit.pressed ? 0.97 : 1
            Glide on scale { duration: Theme.animationDuration(140) }

            Item
            {
                id: home
                anchors.fill: parent
                opacity: Math.max(0, 1 - island.eventReveal / 0.65)
                visible: opacity > 0

                Column
                {
                    objectName: "islandRestingClock"
                    anchors.centerIn: parent
                    spacing: 1
                    width: Math.max(0, parent.width - (island.vertical ? 0 : island.playing ? 62 : 12))

                    ShellText
                    {
                        objectName: "islandClockTime"
                        width: parent.width
                        label: island.stackedClock ? island.timeText : island.inlineClock
                        horizontalAlignment: Text.AlignHCenter
                        font.features: ({tnum: 1})
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 7
                        size: island.vertical ? 10 : 12
                        color: Theme.text1
                    }
                    ShellText
                    {
                        objectName: "islandClockDate"
                        width: parent.width
                        label: island.stackedClock ? (island.vertical ? island.compactDate : island.fullDate) : ""
                        horizontalAlignment: Text.AlignHCenter
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 7
                        size: island.vertical ? 9 : 10
                        color: Theme.text3
                    }
                }

                ClippingRectangle
                {
                    id: cover
                    objectName: "islandAlbumCover"
                    visible: opacity > 0
                    opacity: island.mediaReveal
                    x: island.vertical ? (parent.width - width) / 2 : 2
                    y: island.vertical ? 1 : (parent.height - height) / 2
                    width: island.vertical ? 23 : 26
                    height: width
                    radius: 7
                    color: Theme.inkAlpha(0.08)

                    Image
                    {
                        id: art
                        anchors.fill: parent
                        source: cover.visible ? ServiceMedia.art : ""
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    ShellIcon
                    {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        icon: Icon.music
                        size: 15
                    }
                }
                Equalizer
                {
                    objectName: "islandEqualizer"
                    x: island.vertical ? (parent.width - width) / 2 : parent.width - width - 3
                    y: island.vertical ? parent.height - height - 2 : (parent.height - height) / 2
                    width: 18
                    height: 14
                    radius: 1
                    bars: 4
                    active: island.playing && home.visible
                    visible: opacity > 0
                    opacity: island.mediaReveal
                    style: Enums.EqualizerBars
                    topColor: Theme.inkAlpha(0.55)
                    bottomColor: Theme.inkAlpha(0.85)
                }
            }

            Item
            {
                id: message
                objectName: "islandEvent"
                anchors.fill: parent
                opacity: Math.max(0, (island.eventReveal - 0.22) / 0.78)
                visible: opacity > 0
                clip: true

                readonly property int iconSize: island.notification ? 34 : 24
                readonly property int sideInset: 6

                Item
                {
                    id: messageIcon
                    x: message.sideInset
                    y: island.notification ? eventText.y + 1 : Math.round((parent.height - height) / 2)
                    width: message.iconSize
                    height: width

                    NotificationIcon
                    {
                        anchors.centerIn: parent
                        visible: island.notification
                        n: island.event.notification || null
                        size: parent.width
                    }
                    ShellIcon
                    {
                        anchors.centerIn: parent
                        visible: !island.notification
                        icon: island.event.icon || ""
                        size: 19
                    }
                }
                Column
                {
                    id: eventText
                    x: messageIcon.x + messageIcon.width + 8
                    y: Math.round((message.height - height) / 2)
                    width: Math.max(0, message.width - x - (island.notification ? 25 : 9))
                    spacing: 2

                    ShellText
                    {
                        id: eventTitle
                        objectName: "islandTitle"
                        width: parent.width
                        label: island.event.title || ""
                        color: Theme.text1
                        font.weight: Font.Medium
                        wrapMode: island.notification ? Text.Wrap : Text.NoWrap
                        maximumLineCount: island.notification ? 2 : 1
                    }
                    ShellText
                    {
                        id: eventDetail
                        objectName: "islandBody"
                        width: parent.width
                        label: island.event.subtitle || ""
                        color: Theme.text3
                        size: 10
                        wrapMode: island.notification ? Text.Wrap : Text.NoWrap
                        maximumLineCount: island.notification ? 3 : 1
                    }
                    Rectangle
                    {
                        visible: island.event.kind === "osd" && island.event.value >= 0
                        width: parent.width
                        height: 2
                        radius: 1
                        color: Theme.inkAlpha(0.15)

                        Rectangle
                        {
                            width: parent.width * Math.max(0, Math.min(1, Number(island.event.value) || 0))
                            height: parent.height
                            radius: 1
                            color: Theme.text1
                            Glide on width { duration: Theme.animationDuration(160) }
                        }
                    }
                }
                MouseArea
                {
                    x: 0; y: eventText.y
                    width: eventText.x + eventText.width
                    height: eventText.height
                    visible: island.notification && island.eventWanted
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceIsland.activate()
                }
                MouseArea
                {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 28
                    visible: island.notification && island.eventWanted
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    ShellIcon { anchors.centerIn: parent; icon: Icon.close; size: 11; opacity: parent.containsMouse ? 1 : 0.55 }
                    onClicked: ServiceIsland.dismiss()
                }
            }

            Rectangle
            {
                objectName: "recordingMark"
                anchors { top: parent.top; right: parent.right; topMargin: 1; rightMargin: 1 }
                width: 7
                height: width
                radius: width / 2
                color: Theme.colorCritical
                visible: island.active && opacity > 0
                opacity: island.captureReveal
                Accessible.role: Accessible.StaticText
                Accessible.name: (ServiceIsland.recordingActive ? Tr.tr("recording.active") : "")
                    + (ServiceIsland.cameraActive ? (ServiceIsland.recordingActive ? ", " : "") + Tr.tr("recording.cameraActive") : "")
            }
        }
    }
}
