import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

import "../../components"
import "../../core"
import "../../services"

Item
{
    id: wallpapersContent

    property real reveal: 1

    property var  images: []
    property bool loading: true
    property int  index: 0

    property real pos: 0
    property bool dragging: false
    property bool instant: true

    Ease on pos
    {
        enabled: Config.animationsEnabled && !wallpapersContent.dragging && !wallpapersContent.instant
        duration: 480
        curve: [0.3, 0.0, 0.1, 1.0, 1.0, 1.0]
    }

    property real entrance: 0
    readonly property real rise: Math.min(entrance, reveal)

    function begin() { if (entrance === 0 && !enter.running) enter.start() }

    NumberAnimation
    {
        id: enter
        target: wallpapersContent
        property: "entrance"
        to: 1
        duration: Config.animationsFluid ? 640 : Config.animationsEnabled ? Theme.animationDurationOpen : 0
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easingEmphasized
    }
    Timer { id: fallback; interval: 240; onTriggered: wallpapersContent.begin() }

    readonly property string folder: String(Config.wallpaperDirectory || "").replace(/^~(?=\/|$)/, Quickshell.env("HOME"))

    readonly property real aspect: width > 0 && height > 0 ? width / height : 16 / 9
    readonly property real cardW: Math.round(Math.min(width * 0.46, height * 0.52 * aspect))
    readonly property real cardH: Math.round(cardW / aspect)
    readonly property real cardY: Math.round((height - cardH) / 2 - 24)
    readonly property real step: cardW * 0.66

    function offsetOf(d)
    {
        const a = Math.abs(d);
        const off = a <= 1 ? a * step : step + (a - 1) * step * 0.45;
        return d < 0 ? -off : off;
    }

    function select(i)
    {
        if (images.length === 0) return;
        index = Math.max(0, Math.min(images.length - 1, i));
        pos = index;
    }
    function apply(i)
    {
        const path = images[i];
        if (!path) return;

        ServiceAppearance.applyWallpaper(path);
        OverlayState.hide("wallpapers");
    }
    function nameOf(path) { return String(path).replace(/^.*\//, "").replace(/\.[^.]+$/, "") }

    Process
    {
        running: wallpapersContent.folder !== ""
        command: ["find", "-L", wallpapersContent.folder, "-maxdepth", "3", "-type", "f", "(",
                  "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", "-o", "-iname", "*.bmp", ")"]

        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const list = text.split("\n").filter(l => l !== "");
                list.sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
                wallpapersContent.images = list;
                wallpapersContent.loading = false;

                const current = list.indexOf(Config.wallpaperCurrent);
                wallpapersContent.index = Math.max(0, current);
                wallpapersContent.pos = wallpapersContent.index;
                wallpapersContent.instant = false;

                if (list.length === 0) wallpapersContent.begin();
                else fallback.start();
            }
        }
        onExited: code => { if (code !== 0) { wallpapersContent.loading = false; wallpapersContent.begin() } }
    }

    focus: true
    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: event =>
    {
        if (event.key === Qt.Key_Left)                                        select(index - 1);
        else if (event.key === Qt.Key_Right)                                  select(index + 1);
        else if (event.key === Qt.Key_Home)                                   select(0);
        else if (event.key === Qt.Key_End)                                    select(images.length - 1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)   apply(index);
        else if (event.key === Qt.Key_Escape)                                 OverlayState.hide("wallpapers");
        else return;
        event.accepted = true;
    }

    property real wheelRest: 0
    WheelHandler
    {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event =>
        {
            const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? -event.angleDelta.x : event.angleDelta.y;
            wallpapersContent.wheelRest += delta;
            const steps = wallpapersContent.wheelRest > 0 ? Math.floor(wallpapersContent.wheelRest / 120) : Math.ceil(wallpapersContent.wheelRest / 120);
            wallpapersContent.wheelRest -= steps * 120;
            if (steps !== 0) wallpapersContent.select(wallpapersContent.index - steps);
        }
    }

    property real dragStart: 0
    DragHandler
    {
        id: drag

        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged:
        {
            if (active)
            {
                wallpapersContent.dragging = true;
                wallpapersContent.dragStart = wallpapersContent.pos;
            }
            else
            {
                wallpapersContent.dragging = false;
                wallpapersContent.select(Math.round(wallpapersContent.pos));
            }
        }
        onTranslationChanged: if (active) wallpapersContent.pos = Math.max(-0.4, Math.min(wallpapersContent.images.length - 0.6, wallpapersContent.dragStart - translation.x / wallpapersContent.step))
    }

    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 * wallpapersContent.reveal }

    MouseArea { anchors.fill: parent; onClicked: OverlayState.hide("wallpapers") }

    Item
    {
        id: stage

        anchors.fill: parent

        Repeater
        {
            model: wallpapersContent.images

            Item
            {
                id: card

                required property string modelData
                required property int    index

                readonly property real d: index - wallpapersContent.pos
                readonly property real ad: Math.abs(d)
                readonly property bool centered: index === wallpapersContent.index

                readonly property real rise: Config.animationsFluid ? Math.max(0, Math.min(1, wallpapersContent.rise * 1.75 - ad * 0.25)) : wallpapersContent.rise

                visible: ad < 3.6 && rise > 0.01
                z: 100 - ad * 10

                width: wallpapersContent.cardW
                height: wallpapersContent.cardH

                x: wallpapersContent.width / 2 - width / 2 + wallpapersContent.offsetOf(d)
                y: wallpapersContent.cardY + (1 - rise) * 46

                opacity: rise * Math.max(0, Math.min(1, 3.4 - ad))

                property real hover: hit.containsMouse && card.centered ? 1.02 : 1
                Spring on hover {}
                scale: (1 - Math.min(ad, 3) * 0.2) * (0.9 + 0.1 * rise) * hover

                transform: Rotation
                {
                    origin.x: card.width / 2
                    origin.y: card.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: -Math.max(-1, Math.min(1, card.d)) * 38
                }

                Rectangle
                {
                    anchors.fill: frame
                    anchors.margins: -1
                    anchors.topMargin: 10
                    radius: frame.radius
                    color: Qt.rgba(0, 0, 0, 0.35)
                    opacity: Math.max(0, 1 - card.ad * 0.5)
                }

                ClippingRectangle
                {
                    id: frame

                    anchors.fill: parent
                    radius: 20
                    color: Theme.colorSolid
                    border.color: card.centered ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    Loader
                    {
                        id: picture

                        readonly property bool ready: item !== null && item.status === Image.Ready

                        anchors.fill: parent
                        active: card.ad < 3.5

                        sourceComponent: Image
                        {
                            source: "file://" + card.modelData
                            sourceSize.width: Math.round(wallpapersContent.cardW * 1.3)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true

                            cache: false
                            smooth: true
                            mipmap: true

                            readonly property real near: Config.animationsFluid ? Math.min(1, card.ad) : 0
                            x: Config.animationsFluid ? -card.d * wallpapersContent.cardW * 0.06 : 0
                            scale: 1.12 + 0.06 * near

                            opacity: status === Image.Ready ? 1 : 0
                            onStatusChanged: if (status !== Image.Loading && card.centered) wallpapersContent.begin()
                            Smooth on opacity { duration: 260 }
                        }
                    }

                    Rectangle
                    {
                        anchors.fill: parent
                        color: Theme.colorField
                        visible: !picture.ready
                        opacity: 1
                        SequentialAnimation on opacity
                        {
                            running: card.visible && !picture.ready
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.5; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1;   duration: 700; easing.type: Easing.InOutSine }
                        }
                        z: -1
                    }

                    Rectangle
                    {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: Math.min(1, card.ad) * 0.5
                    }
                }

                MouseArea
                {
                    id: hit

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.centered ? wallpapersContent.apply(card.index) : wallpapersContent.select(card.index)
                }
            }
        }
    }

    component Arrow: Rectangle
    {
        id: arrow

        property string icon: ""
        signal clicked()

        width: 46
        height: 46
        radius: 23
        color: area.pressed ? Theme.colorPressed : area.containsMouse ? Theme.colorHoverStrong : Qt.rgba(0, 0, 0, 0.35)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        opacity: (enabled ? 1 : 0.3) * Math.max(0, Math.min(1, wallpapersContent.rise * 2 - 0.8))
        Tint on color {}

        scale: area.pressed ? 0.92 : area.containsMouse ? 1.12 : 1
        Spring on scale {}

        ShellIcon { anchors.centerIn: parent; icon: arrow.icon; size: 18; zoom: 1.15 }

        MouseArea
        {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: arrow.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.clicked()
        }
    }

    Arrow
    {
        icon: Icon.chevronLeft
        enabled: wallpapersContent.index > 0
        x: Math.round(wallpapersContent.width / 2 - wallpapersContent.cardW / 2 - width - 28)
        y: Math.round(wallpapersContent.cardY + (wallpapersContent.cardH - height) / 2)
        z: 200
        onClicked: wallpapersContent.select(wallpapersContent.index - 1)
    }
    Arrow
    {
        icon: Icon.chevronRight
        enabled: wallpapersContent.index < wallpapersContent.images.length - 1
        x: Math.round(wallpapersContent.width / 2 + wallpapersContent.cardW / 2 + 28)
        y: Math.round(wallpapersContent.cardY + (wallpapersContent.cardH - height) / 2)
        z: 200
        onClicked: wallpapersContent.select(wallpapersContent.index + 1)
    }

    Rectangle
    {
        anchors.centerIn: caption
        width: caption.width + 36
        height: caption.height + 18
        radius: height / 2
        color: Theme.colorSolid
        opacity: 0.85 * caption.opacity
        visible: wallpapersContent.images.length > 0
    }

    Column
    {
        id: caption

        anchors.horizontalCenter: parent.horizontalCenter
        y: wallpapersContent.cardY + wallpapersContent.cardH + 34
        spacing: 6
        opacity: Math.max(0, Math.min(1, wallpapersContent.rise * 2 - 1))

        ShellText
        {
            id: title

            property string name: ""
            anchors.horizontalCenter: parent.horizontalCenter
            label: name
            size: 15
            color: Theme.text1
            font.weight: Font.Medium

            Connections
            {
                target: wallpapersContent
                function onIndexChanged() { swap.restart() }
                function onImagesChanged() { title.name = wallpapersContent.nameOf(wallpapersContent.images[wallpapersContent.index] || ""); }
            }
            SequentialAnimation
            {
                id: swap
                NumberAnimation { target: title; property: "opacity"; to: 0; duration: Config.animationsEnabled ? 80 : 0 }
                ScriptAction { script: title.name = wallpapersContent.nameOf(wallpapersContent.images[wallpapersContent.index] || "") }
                NumberAnimation { target: title; property: "opacity"; to: 1; duration: Config.animationsEnabled ? 180 : 0; easing.type: Easing.OutCubic }
            }
        }
        ShellText
        {
            anchors.horizontalCenter: parent.horizontalCenter
            label: wallpapersContent.images.length > 0 ? (wallpapersContent.index + 1) + " / " + wallpapersContent.images.length : ""
            size: 11
            color: Theme.text3
            font.family: Theme.fontMono
        }
    }

    ShellText
    {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        label: wallpapersContent.images.length > 0 ? "←  →  browse   ·   Enter  apply   ·   Esc  close" : ""
        size: 11
        color: Theme.text4
        opacity: Math.max(0, Math.min(1, wallpapersContent.rise * 2 - 1))
    }

    Column
    {
        visible: !wallpapersContent.loading && wallpapersContent.images.length === 0
        anchors.centerIn: parent
        spacing: 14
        opacity: wallpapersContent.reveal

        ShellIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: Icon.wallpapers; size: 40; opacity: 0.6 }
        ShellText { anchors.horizontalCenter: parent.horizontalCenter; label: Tr.tr("wallpapers.noImagesIn").arg(wallpapersContent.folder); size: 14; color: Theme.text2 }
        ShellText { anchors.horizontalCenter: parent.horizontalCenter; label: Tr.tr("wallpapers.chooseTheFolderIn"); size: 12; color: Theme.text3 }
    }
}
