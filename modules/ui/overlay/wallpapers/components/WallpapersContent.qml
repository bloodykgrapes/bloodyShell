import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

import "../../../../animations"
import "../../../../common"
import "../../../../core"
import "../../../../services"

Item
{
    id: wallpapersContent
    objectName: "wallpapersContent"

    property real reveal: 1
    property var images: []
    property bool loading: true
    property string scanError: ""
    property int index: 0
    property real pos: 0
    property bool dragging: false
    property bool instant: true
    property bool ready: false
    property real entrance: 0

    readonly property real rise: Math.min(Config.animationsEnabled ? entrance : 1, reveal)
    readonly property string folder: String(Config.wallpaperDirectory || "").replace(/^~(?=\/|$)/, Quickshell.env("HOME"))
    readonly property string selectedPath: images[index] || ""
    readonly property bool current: selectedPath !== "" && selectedPath === Config.wallpaperCurrent
    readonly property real aspect: width > 0 && height > 0 ? width / height : 16 / 9
    readonly property real cardW: Math.round(Math.min(width * 0.44, height * 0.58 * aspect))
    readonly property real cardH: Math.round(cardW / aspect)
    readonly property real cardY: Math.round((height - cardH) / 2 - 24)
    readonly property real step: cardW * 0.57

    Ease on pos
    {
        enabled: Config.animationsEnabled && !wallpapersContent.dragging && !wallpapersContent.instant
        duration: Theme.animationDurationMorph
    }
    NumberAnimation
    {
        id: enter
        target: wallpapersContent
        property: "entrance"
        to: 1
        duration: Config.animationsEnabled ? Theme.animationDurationControl : 0
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easingEmphasized
    }

    function begin() { if (entrance === 0 && !enter.running) enter.start(); }
    function distanceOf(i)
    {
        if (images.length === 0) return 0;
        let distance = (i - pos) % images.length;
        if (distance > images.length / 2) distance -= images.length;
        if (distance < -images.length / 2) distance += images.length;
        return distance;
    }
    function offsetOf(distance)
    {
        const amount = Math.abs(distance);
        const offset = Math.min(amount, 1) * step + Math.max(0, amount - 1) * cardW * 0.32;
        return distance < 0 ? -offset : offset;
    }
    function select(i)
    {
        if (images.length === 0 || ServiceAppearance.wallpaperBusy) return;
        index = ((i % images.length) + images.length) % images.length;
        pos += distanceOf(index);
    }
    function apply(i)
    {
        const path = images[i];
        if (!path || path === Config.wallpaperCurrent || ServiceAppearance.wallpaperBusy) return;
        ServiceAppearance.applyWallpaper(path);
    }
    function nameOf(path) { return String(path).replace(/^.*\//, "").replace(/\.[^.]+$/, ""); }
    function scanFolder()
    {
        scanError = "";
        loading = folder !== "";
        if (folder === "") { images = []; index = 0; pos = 0; return; }
        if (scan.busy) return;
        scan.folder = folder;
        scan.selection = selectedPath || Config.wallpaperCurrent;
        scan.run(Paths.commandFor("wallpaper", ["list", folder]));
    }
    onFolderChanged: if (ready) scanFolder()

    CommandProcess
    {
        id: scan
        property string folder: ""
        property string selection: ""
        stdout: StdioCollector { id: catalog }
        onCompleted: code =>
        {
            if (folder !== wallpapersContent.folder) { Qt.callLater(wallpapersContent.scanFolder); return; }
            let paths = [];
            if (code === 0)
            {
                try { paths = JSON.parse(catalog.text).paths.sort((a, b) => a.localeCompare(b, undefined, {numeric: true})); }
                catch (error) { wallpapersContent.scanError = Tr.tr("wallpapers.readFailed"); }
            }
            else wallpapersContent.scanError = scan.errorMessage(Tr.tr("wallpapers.readFailed"));
            wallpapersContent.instant = true;
            wallpapersContent.images = paths;
            const selected = paths.indexOf(selection), current = paths.indexOf(Config.wallpaperCurrent);
            wallpapersContent.index = Math.max(0, selected >= 0 ? selected : current);
            wallpapersContent.pos = wallpapersContent.index;
            wallpapersContent.wheelRest = 0;
            wallpapersContent.instant = false;
            wallpapersContent.loading = false;
        }
    }
    Connections
    {
        target: ServiceAppearance
        function onWallpaperApplied() { OverlayState.hide("wallpapers"); }
    }

    focus: true
    Component.onCompleted: { ready = true; forceActiveFocus(); begin(); scanFolder(); }
    Keys.onPressed: event =>
    {
        if (event.key === Qt.Key_Left) select(index - 1);
        else if (event.key === Qt.Key_Right) select(index + 1);
        else if (event.key === Qt.Key_Home) select(0);
        else if (event.key === Qt.Key_End) select(images.length - 1);
        else if (event.key === Qt.Key_F5) scanFolder();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) apply(index);
        else if (event.key === Qt.Key_Escape) OverlayState.hide("wallpapers");
        else return;
        event.accepted = true;
    }

    property real wheelRest: 0
    function scroll(pixelDelta, angleDelta)
    {
        const delta = Config.scrollDelta(pixelDelta, angleDelta);
        if (delta * wheelRest < 0) wheelRest = 0;
        wheelRest += delta;
        const steps = Math.trunc(wheelRest / 48);
        wheelRest -= steps * 48;
        if (steps !== 0) select(index - steps);
    }
    WheelHandler
    {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event =>
        {
            if (event.pixelDelta.x !== 0 || event.angleDelta.x !== 0) { event.accepted = false; return; }
            wallpapersContent.scroll(event.pixelDelta.y, event.angleDelta.y);
            event.accepted = true;
        }
    }
    WheelHandler
    {
        target: null
        orientation: Qt.Horizontal
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event =>
        {
            wallpapersContent.scroll(-event.pixelDelta.x, -event.angleDelta.x);
            event.accepted = true;
        }
    }

    Item
    {
        id: gallery
        objectName: "wallpaperGallery"
        anchors.fill: parent

        MouseArea
        {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: OverlayState.hide("wallpapers")
        }

        DragHandler
        {
            id: drag
            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            enabled: wallpapersContent.images.length > 1 && !ServiceAppearance.wallpaperBusy
            property real start: 0
            onActiveChanged:
            {
                wallpapersContent.dragging = active;
                if (active) start = wallpapersContent.pos;
                else wallpapersContent.select(Math.round(wallpapersContent.pos));
            }
            onTranslationChanged: if (active) wallpapersContent.pos = start - translation.x / wallpapersContent.step
        }

        Repeater
        {
            model: wallpapersContent.images
            Item
            {
                id: card
                required property string modelData
                required property int index
                objectName: "wallpaperCard-" + index
                readonly property real distance: wallpapersContent.distanceOf(index)
                readonly property real depth: Math.abs(distance)
                readonly property bool selected: index === wallpapersContent.index
                readonly property real shown: Math.max(0, Math.min(1, 3 - depth))
                readonly property real arrival: Config.animationsFluid ? Math.max(0, Math.min(1, wallpapersContent.rise * 1.5 - depth * 0.15)) : wallpapersContent.rise
                property real hover: hit.containsMouse && selected && !wallpapersContent.dragging ? 1.02 : 1
                Spring on hover {}

                visible: shown > 0.001
                opacity: arrival * shown
                width: wallpapersContent.cardW
                height: wallpapersContent.cardH
                x: wallpapersContent.width / 2 - width / 2 + wallpapersContent.offsetOf(distance)
                y: wallpapersContent.cardY + (1 - arrival) * 32
                z: 100 - depth * 10
                scale: (1 - Math.min(depth, 2.5) * 0.23) * (0.94 + 0.06 * arrival) * hover
                transform: Rotation
                {
                    origin.x: card.width / 2
                    origin.y: card.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: -Math.max(-1, Math.min(1, card.distance)) * Math.min(44, card.depth * 32)
                }
                Accessible.role: Accessible.Button
                Accessible.name: wallpapersContent.nameOf(modelData)
                Accessible.description: modelData
                Accessible.onPressAction: selected ? wallpapersContent.apply(index) : wallpapersContent.select(index)

                Rectangle
                {
                    anchors.fill: frame
                    anchors.margins: -1
                    anchors.topMargin: 10
                    radius: frame.radius
                    color: Qt.rgba(0, 0, 0, 0.35)
                    opacity: Math.max(0, 1 - card.depth * 0.35)
                }
                ClippingRectangle
                {
                    id: frame
                    anchors.fill: parent
                    radius: 20
                    color: Theme.colorSolid
                    border.width: 1
                    border.color: card.selected ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(1, 1, 1, 0.1)
                    ShellIcon { anchors.centerIn: parent; icon: Icon.wallpapers; size: 28; opacity: 0.35 }
                    Loader
                    {
                        anchors.fill: parent
                        active: card.visible
                        sourceComponent: WallpaperImage
                        {
                            wallpaper: card.modelData
                            sourceSize: Qt.size(Math.round(wallpapersContent.cardW * 1.5), Math.round(wallpapersContent.cardH * 1.5))
                            opacity: status === Image.Ready ? 1 : 0
                            scale: 1.02
                            Smooth on opacity { duration: 220 }
                        }
                    }
                    Rectangle
                    {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: Math.min(1, card.depth) * 0.25
                    }
                    Rectangle
                    {
                        anchors { right: parent.right; top: parent.top; margins: 12 }
                        width: 28; height: 28; radius: 9
                        visible: card.modelData === Config.wallpaperCurrent
                        color: Qt.rgba(0, 0, 0, 0.5)
                        ShellIcon { anchors.centerIn: parent; icon: wallpapersContent.lightIcon(Icon.check); size: 14 }
                    }
                    Rectangle
                    {
                        anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
                        width: 28; height: 28; radius: 9
                        visible: ServiceAppearance.isVideo(card.modelData)
                        color: Qt.rgba(0, 0, 0, 0.5)
                        ShellIcon { anchors.centerIn: parent; icon: wallpapersContent.lightIcon(Icon.mediaPlay); size: 14 }
                        Accessible.name: Tr.tr("wallpapers.video")
                    }
                }
                MouseArea
                {
                    id: hit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !ServiceAppearance.wallpaperBusy
                    onClicked:
                    {
                        wallpapersContent.forceActiveFocus(Qt.MouseFocusReason);
                        card.selected ? wallpapersContent.apply(card.index) : wallpapersContent.select(card.index);
                    }
                }
            }
        }
    }

    function lightIcon(icon) { return String(icon).replace("/icons/dark/", "/icons/light/"); }
    component Arrow: ActionButton
    {
        iconOnly: true
        width: 46; height: 46; radius: 23
        iconSize: 18
        color: Qt.rgba(0, 0, 0, 0.35)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        visible: wallpapersContent.images.length > 1
        enabled: wallpapersContent.images.length > 1 && !ServiceAppearance.wallpaperBusy
        opacity: (enabled ? 1 : 0.3) * wallpapersContent.rise
        autoRepeat: true
    }
    Arrow
    {
        objectName: "wallpaperPrevious"
        icon: wallpapersContent.lightIcon(Icon.chevronLeft)
        text: Tr.tr("wallpapers.previous")
        x: Math.round(wallpapersContent.width / 2 - wallpapersContent.cardW / 2 - width - 24)
        y: Math.round(wallpapersContent.cardY + (wallpapersContent.cardH - height) / 2)
        onClicked: wallpapersContent.select(wallpapersContent.index - 1)
    }
    Arrow
    {
        objectName: "wallpaperNext"
        icon: wallpapersContent.lightIcon(Icon.chevronRight)
        text: Tr.tr("wallpapers.next")
        x: Math.round(wallpapersContent.width / 2 + wallpapersContent.cardW / 2 + 24)
        y: Math.round(wallpapersContent.cardY + (wallpapersContent.cardH - height) / 2)
        onClicked: wallpapersContent.select(wallpapersContent.index + 1)
    }

    Rectangle
    {
        id: captionBackground
        objectName: "wallpaperCaptionBackground"
        anchors.centerIn: caption
        width: caption.width + 32
        height: caption.height + 18
        radius: height / 2
        color: Theme.colorSolid
        opacity: wallpapersContent.rise
        visible: wallpapersContent.images.length > 0
    }
    Column
    {
        id: caption
        anchors.horizontalCenter: parent.horizontalCenter
        y: wallpapersContent.cardY + wallpapersContent.cardH + 30
        width: Math.min(Math.max(title.implicitWidth, counter.implicitWidth), Math.max(0, parent.width - 64))
        spacing: 5
        visible: wallpapersContent.images.length > 0
        opacity: wallpapersContent.rise
        ShellText
        {
            id: title
            objectName: "wallpaperName"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            label: wallpapersContent.nameOf(wallpapersContent.selectedPath)
            color: Theme.text1
            size: 15
            font.weight: Font.Medium
        }
        ShellText
        {
            id: counter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            label: (wallpapersContent.index + 1) + " / " + wallpapersContent.images.length + (wallpapersContent.current ? " · " + Tr.tr("wallpapers.current") : "")
            color: Theme.text3
            size: 11
            font.family: Theme.fontMono
        }
    }
    ShellText
    {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 34 }
        width: parent.width - 48
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        label: wallpapersContent.images.length > 0 ? Tr.tr("wallpapers.shortcuts") : ""
        size: 11
        color: Qt.rgba(1, 1, 1, 0.5)
        opacity: wallpapersContent.rise
    }
    ShellText
    {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
        width: parent.width - 48
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        label: ServiceAppearance.wallpaperBusy ? Tr.tr("wallpapers.applying") : wallpapersContent.scanError || ServiceAppearance.wallpaperError
        color: ServiceAppearance.wallpaperBusy ? Qt.rgba(1, 1, 1, 0.8) : "#ff8c8c"
        size: 11
    }
    Column
    {
        visible: wallpapersContent.images.length === 0
        anchors.centerIn: parent
        width: parent.width - 64
        spacing: 12
        opacity: wallpapersContent.rise
        ShellIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: wallpapersContent.lightIcon(Icon.wallpapers); size: 40; opacity: 0.5 }
        ShellText
        {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            label: wallpapersContent.loading ? Tr.tr("common.loading") : Tr.tr("wallpapers.noImagesIn").arg(wallpapersContent.folder)
            color: Qt.rgba(1, 1, 1, 0.8)
            size: 14
        }
        ShellText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; label: wallpapersContent.loading ? "" : Tr.tr("wallpapers.folderHint"); color: Qt.rgba(1, 1, 1, 0.6) }
    }
}
