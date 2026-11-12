import QtQuick
import Quickshell
import Quickshell.Widgets

import "../../animations"
import "../../common"
import "../../core"
import "../../services"
import "../bar/components"

Widget
{
    id: island
    objectName: "dynamicIsland"

    menu: Qt.resolvedUrl("../bar/menus/MenuMedia.qml")
    readonly property string output: QsWindow.window && QsWindow.window.screen ? QsWindow.window.screen.name : ""
    readonly property var presentation: menuOpen ? ServiceIsland.mediaView() : ServiceIsland.view(output)
    property var shown: ({ kind: "", title: "", subtitle: "", icon: "", value: -1 })
    property var pending: presentation
    property real contentOpacity: 1
    property real contentShift: 0
    property bool wasEmpty: true
    readonly property bool notification: shown.kind === "notification"
    readonly property real limit:
    {
        for (let item = parent; item; item = item.parent)
            if (item.centerLimit !== undefined) return Math.min(300, Math.max(32, item.centerLimit - Theme.barPadding * 2));
        return 300;
    }
    readonly property bool compact: !notification && (vertical || limit < 120)
    readonly property real menuProgress:
    {
        for (let item = parent; item; item = item.parent)
            if (item.isIsland) return item.progress;
        return 0;
    }
    implicitWidth: vertical && !notification ? 32 : hit.implicitWidth
    implicitHeight: hit.implicitHeight
    active: menuOpen || presentation.kind !== ""

    function present(next)
    {
        if (next.kind === "" || (menuOpen && next.title === "")) return;
        pending = next;
        const unchanged = shown.kind === next.kind && (next.kind === "osd"
            || (shown.title === next.title && shown.subtitle === next.subtitle && shown.notification === next.notification));
        if (unchanged || wasEmpty || !Config.animationsEnabled)
        {
            if (!Config.animationsEnabled) { change.stop(); contentOpacity = 1; contentShift = 0; }
            shown = next;
        }
        else if (!change.running) change.start();
        wasEmpty = false;
    }

    onPresentationChanged:
    {
        if (presentation.kind === "") { change.stop(); contentOpacity = 1; contentShift = 0; wasEmpty = true; }
        else present(presentation);
    }
    Component.onCompleted: if (active) present(presentation)
    onMenuOpenChanged: ServiceIsland.setMediaMenu(island, menuOpen)
    Component.onDestruction: ServiceIsland.setMediaMenu(island, false)

    Connections
    {
        target: Config
        function onAnimationsEnabledChanged()
        {
            if (Config.animationsEnabled) return;
            change.stop();
            island.shown = island.pending;
            island.contentOpacity = 1;
            island.contentShift = 0;
        }
    }

    SequentialAnimation
    {
        id: change
        ParallelAnimation
        {
            NumberAnimation { target: island; property: "contentOpacity"; to: 0; duration: 80; easing.type: Easing.InCubic }
            NumberAnimation { target: island; property: "contentShift"; to: -4; duration: 80; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { island.shown = island.pending; island.contentShift = Config.animationsFluid ? 10 : 5; } }
        ParallelAnimation
        {
            NumberAnimation { target: island; property: "contentOpacity"; to: 1; duration: Theme.animationDurationControl; easing.type: Easing.OutCubic }
            NumberAnimation { target: island; property: "contentShift"; to: 0; duration: Theme.animationDurationMorph; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
        }
        onFinished: if (island.pending !== island.shown) island.present(island.pending)
    }

    MouseArea
    {
        id: hit
        objectName: "islandCompactContent"
        visible: !island.menuOpen
        implicitWidth: island.notification
            ? island.vertical ? Math.min(340, Math.max(160, (QsWindow.window ? QsWindow.window.width : 400) - 64)) : island.limit
            : island.vertical ? 32 : Math.min(island.limit, Math.max(130, textProbe.advanceWidth + 76))
        implicitHeight: island.notification ? Math.max(84, textColumn.implicitHeight + 24) : 32
        hoverEnabled: true
        acceptedButtons: island.shown.kind === "osd" ? Qt.NoButton : Qt.LeftButton | Qt.MiddleButton
        cursorShape: acceptedButtons !== Qt.NoButton ? Qt.PointingHandCursor : Qt.ArrowCursor
        opacity: island.contentOpacity * (1 - island.menuProgress)
        transform: Translate
        {
            x: island.vertical ? island.contentShift * (island.side === Enums.EdgeLeft ? 1 : -1) : 0
            y: island.vertical ? 0 : island.contentShift * (island.side === Enums.EdgeTop ? 1 : -1)
        }
        scale: pressed ? 0.97 : 1
        Spring on scale {}

        Accessible.role: Accessible.Button
        Accessible.name: (island.shown.title || "") + " " + (island.shown.subtitle || "")
        onClicked: mouse =>
        {
            if (island.shown.kind === "notification") ServiceIsland.activate();
            else if (mouse.button === Qt.MiddleButton) ServiceMedia.toggle();
            else island.toggleMenu();
        }
        onWheel: wheel =>
        {
            if (island.shown.kind !== "media") return;
            const steps = island.wheelSteps(wheel);
            if (steps > 0) ServiceMedia.previous();
            else if (steps < 0) ServiceMedia.next();
        }

        TextMetrics { id: textProbe; text: island.shown.title || ""; font.family: Theme.fontText; font.pixelSize: 12 }

        ClippingRectangle
        {
            id: cover
            x: island.compact ? (hit.width - width) / 2 : island.notification ? 10 : 3
            y: island.notification ? 12 : (hit.height - height) / 2
            width: island.notification ? 40 : 28
            height: width
            radius: island.notification ? 12 : 9
            color: Theme.inkAlpha(0.07)

            Image
            {
                id: art
                anchors.fill: parent
                source: !island.menuOpen && island.shown.kind === "media" ? island.shown.art || "" : ""
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            NotificationIcon
            {
                anchors.centerIn: parent
                visible: island.shown.kind === "notification"
                n: island.shown.notification || null
                size: cover.width
            }
            ShellIcon
            {
                anchors.centerIn: parent
                visible: island.shown.kind !== "notification" && art.status !== Image.Ready
                icon: island.shown.icon || Icon.music
                size: 16
            }
        }
        Column
        {
            id: textColumn
            visible: !island.compact
            x: cover.x + cover.width + 9
            y: island.notification ? 12 : (hit.height - implicitHeight) / 2
            width: Math.max(0, hit.width - x - 26)
            spacing: island.notification ? 3 : 1
            ShellText
            {
                width: parent.width
                label: island.notification && island.shown.notification ? island.shown.notification.appName || "" : ""
                size: 10
                color: Theme.text3
            }
            ShellText
            {
                objectName: "islandTitle"
                width: parent.width
                label: island.shown.title || ""
                size: island.notification ? 13 : 12
                color: Theme.text1
                font.weight: Font.Medium
                wrapMode: island.notification ? Text.Wrap : Text.NoWrap
                maximumLineCount: island.notification ? 2 : 1
            }
            ShellText
            {
                objectName: "islandBody"
                width: parent.width
                label: island.shown.subtitle || ""
                size: island.notification ? 11 : 10
                color: Theme.text3
                wrapMode: island.notification ? Text.Wrap : Text.NoWrap
                maximumLineCount: island.notification ? 4 : 1
            }
        }
        Equalizer
        {
            objectName: "islandEqualizer"
            style: Enums.EqualizerBars
            anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
            width: 16; height: 15
            bars: 4
            active: island.active && island.shown.kind === "media"
            visible: active && !island.compact
            minimumHeight: 2
            topColor: Theme.inkAlpha(0.35)
            bottomColor: Theme.inkAlpha(0.75)
        }
        Rectangle
        {
            anchors { left: cover.right; leftMargin: 9; right: parent.right; rightMargin: 4; bottom: parent.bottom }
            height: 2; radius: 1
            visible: island.shown.kind === "osd" && island.shown.value >= 0 && !island.compact
            color: Theme.inkAlpha(0.15)
            Rectangle
            {
                width: parent.width * Math.max(0, Math.min(1, Number(island.shown.value) || 0))
                height: parent.height; radius: 1; color: Theme.text1
                Glide on width { duration: 160 }
            }
        }
        MouseArea
        {
            anchors.right: parent.right
            y: 8
            width: 22; height: 28
            visible: island.shown.kind === "notification" && !island.compact
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            ShellIcon { anchors.centerIn: parent; icon: Icon.close; size: 10; opacity: parent.containsMouse ? 1 : 0.5 }
            onClicked: ServiceIsland.dismiss()
        }
    }
}
