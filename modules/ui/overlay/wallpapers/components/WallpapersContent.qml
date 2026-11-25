import QtQuick
import Quickshell.Widgets

import "../../../../animations"
import "../../../../animations/OverlayMotion.js" as Motion
import "../../../../common"
import "../../../../core"
import "../../../../services"

Item
{
    id: wallpapersContent
    objectName: "wallpapersContent"

    property real reveal: 1
    property bool opening: true
    property var images: []
    property int index: 0
    property real targetPos: 0
    property real pos: targetPos
    property bool dragging: false
    property bool instant: true
    property bool ready: false
    property bool catalogLoaded: false
    property real galleryProgress: opening && catalogLoaded ? 1 : 0

    readonly property bool fluid: Config.animationsFluid
    readonly property real galleryReveal: fluid ? Math.min(reveal, galleryProgress) : reveal
    readonly property real chromeOpacity: fluid ? Motion.phase(galleryReveal, 0.48, 0.96) : 1
    readonly property real chromeOffset: 8 * (1 - chromeOpacity)
    readonly property bool pointerReady: !fluid || galleryReveal >= 0.76

    readonly property string folder: ServiceWallpapers.folder
    readonly property bool loading: ServiceWallpapers.loading
    readonly property string scanError: ServiceWallpapers.error
    readonly property string selectedPath: images[index] || ""
    readonly property bool loginWallpaper: OverlayState.wallpaperTarget === "login"
    readonly property string currentWallpaper: loginWallpaper ? ServiceGreeter.selection : Config.wallpaperCurrent
    readonly property bool applying: loginWallpaper ? ServiceGreeter.wallpaperBusy : ServiceAppearance.wallpaperBusy
    readonly property string applyError: loginWallpaper ? ServiceGreeter.wallpaperError : ServiceAppearance.wallpaperError
    readonly property bool current: selectedPath !== "" && selectedPath === currentWallpaper
    readonly property real aspect: width > 0 && height > 0 ? width / height : 16 / 9
    readonly property real cardW: Math.round(Math.min(width * 0.44, height * 0.58 * aspect))
    readonly property real cardH: Math.round(cardW / aspect)
    readonly property real cardY: Math.round((height - cardH) / 2 - 24)
    readonly property real step: cardW * 0.57

    opacity: fluid ? 1 : reveal

    Ease on galleryProgress
    {
        enabled: wallpapersContent.fluid
        duration: wallpapersContent.opening ? Motion.wallpapersOpenDuration : Motion.fluidCloseDuration
        curve: wallpapersContent.opening ? Motion.wallpapersCurve : Motion.fluidCloseCurve
        durationByDistance: true
    }

    Ease on pos
    {
        enabled: Config.animationsEnabled && !wallpapersContent.dragging && !wallpapersContent.instant
        duration: Theme.animationDurationMorph
        curve: [0.28, 0.0, 0.3, 1.0, 1.0, 1.0]
    }

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
        if (images.length === 0 || wallpapersContent.applying) return;
        index = ((i % images.length) + images.length) % images.length;
        targetPos = pos + distanceOf(index);
    }
    function advance(steps)
    {
        if (images.length === 0 || wallpapersContent.applying) return;
        index = (((index + steps) % images.length) + images.length) % images.length;
        targetPos += steps;
    }
    function apply(i)
    {
        const path = images[i];
        if (!path || path === currentWallpaper || wallpapersContent.applying) return;
        if (loginWallpaper) ServiceGreeter.applyWallpaper(path);
        else ServiceAppearance.applyWallpaper(path);
    }
    function nameOf(path) { return String(path).replace(/^.*\//, "").replace(/\.[^.]+$/, ""); }
    function syncCatalog(keepSelection = true)
    {
        const catalog = ServiceWallpapers.catalog;
        const matches = catalog?.folder === folder;
        const paths = !matches ? [] : loginWallpaper ? catalog.paths.filter(path => !ServiceAppearance.isVideo(path)) : catalog.paths;
        if (!keepSelection || paths.length !== images.length || paths.some((path, i) => path !== images[i]))
        {
            const selected = keepSelection ? paths.indexOf(selectedPath) : -1;
            instant = true;
            images = paths;
            index = Math.max(0, selected >= 0 ? selected : paths.indexOf(currentWallpaper));
            targetPos = index;
            wheelRest = 0;
            instant = false;
        }
        if (matches) catalogLoaded = true;
    }

    onFolderChanged:
    {
        if (!ready) return;
        syncCatalog();
        ServiceWallpapers.refresh();
    }
    onLoginWallpaperChanged: if (ready) syncCatalog(false)

    Connections
    {
        target: ServiceWallpapers
        function onCatalogChanged() { if (wallpapersContent.ready) wallpapersContent.syncCatalog() }
    }
    Connections
    {
        target: ServiceAppearance
        function onWallpaperApplied() { if (!wallpapersContent.loginWallpaper) OverlayState.hide("wallpapers"); }
    }

    Connections
    {
        target: ServiceGreeter
        function onWallpaperApplied() { if (wallpapersContent.loginWallpaper) OverlayState.hide("wallpapers"); }
    }

    focus: true
    Component.onCompleted:
    {
        ready = true;
        forceActiveFocus();
        syncCatalog();
        ServiceWallpapers.refresh();
    }
    Keys.onPressed: event =>
    {
        if (event.key === Qt.Key_Left) advance(-1);
        else if (event.key === Qt.Key_Right) advance(1);
        else if (event.key === Qt.Key_Home) select(0);
        else if (event.key === Qt.Key_End) select(images.length - 1);
        else if (event.key === Qt.Key_F5) ServiceWallpapers.refresh(true);
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
        if (steps !== 0) advance(-steps);
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
            enabled: wallpapersContent.pointerReady && wallpapersContent.images.length > 1 && !wallpapersContent.applying
            property real start: 0
            onActiveChanged:
            {
                wallpapersContent.dragging = active;
                if (active) { start = wallpapersContent.pos; wallpapersContent.targetPos = start; }
                else wallpapersContent.select(Math.round(wallpapersContent.pos));
            }
            onTranslationChanged: if (active) wallpapersContent.targetPos = start - translation.x / wallpapersContent.step
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
                readonly property real entranceDelay: Math.min(depth, 2) * 0.18
                readonly property real entrance: wallpapersContent.fluid
                    ? Motion.phase(wallpapersContent.galleryReveal, entranceDelay, entranceDelay + 0.60) : 1
                property real hover: hit.containsMouse && selected && !wallpapersContent.dragging ? 1.02 : 1
                Spring on hover {}

                visible: shown > 0.001
                opacity: shown * entrance
                width: wallpapersContent.cardW
                height: wallpapersContent.cardH
                x: (wallpapersContent.width - width) / 2 + wallpapersContent.offsetOf(distance)
                y: wallpapersContent.cardY + (wallpapersContent.fluid ? 18 * (1 - entrance) : 32 * (1 - wallpapersContent.reveal))
                z: 100 - depth * 10
                scale: (1 - Math.min(depth, 2.5) * 0.23) * hover * (wallpapersContent.fluid ? 1 : 0.94 + 0.06 * wallpapersContent.reveal)
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
                            Smooth on opacity { enabled: Config.animationsEnabled && wallpapersContent.reveal >= 1; duration: 220 }
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
                        visible: card.modelData === wallpapersContent.currentWallpaper
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
                    enabled: wallpapersContent.pointerReady && !wallpapersContent.applying
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
    component Arrow: Button
    {
        iconOnly: true
        width: 46; height: 46; radius: 23
        iconSize: 18
        color: Qt.rgba(0, 0, 0, 0.35)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        visible: wallpapersContent.images.length > 1
        enabled: wallpapersContent.pointerReady && !wallpapersContent.applying
        opacity: wallpapersContent.chromeOpacity * (wallpapersContent.applying ? 0.3 : 1)
        autoRepeat: true
    }
    Arrow
    {
        objectName: "wallpaperPrevious"
        icon: wallpapersContent.lightIcon(Icon.chevronLeft)
        text: Tr.tr("wallpapers.previous")
        x: Math.round(wallpapersContent.width / 2 - wallpapersContent.cardW / 2 - width - 24)
        y: Math.round(wallpapersContent.cardY + (wallpapersContent.cardH - height) / 2) + wallpapersContent.chromeOffset
        onClicked: wallpapersContent.advance(-1)
    }
    Arrow
    {
        objectName: "wallpaperNext"
        icon: wallpapersContent.lightIcon(Icon.chevronRight)
        text: Tr.tr("wallpapers.next")
        x: Math.round(wallpapersContent.width / 2 + wallpapersContent.cardW / 2 + 24)
        y: Math.round(wallpapersContent.cardY + (wallpapersContent.cardH - height) / 2) + wallpapersContent.chromeOffset
        onClicked: wallpapersContent.advance(1)
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
        opacity: wallpapersContent.chromeOpacity
        visible: wallpapersContent.images.length > 0
    }
    Column
    {
        id: caption
        anchors.horizontalCenter: parent.horizontalCenter
        y: wallpapersContent.cardY + wallpapersContent.cardH + 30 + wallpapersContent.chromeOffset
        width: Math.min(Math.max(title.implicitWidth, counter.implicitWidth), Math.max(0, parent.width - 64))
        spacing: 5
        visible: wallpapersContent.images.length > 0
        opacity: wallpapersContent.chromeOpacity
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
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        anchors.bottomMargin: 34 - wallpapersContent.chromeOffset
        width: parent.width - 48
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        label: wallpapersContent.images.length > 0 ? Tr.tr("wallpapers.shortcuts") : ""
        opacity: wallpapersContent.chromeOpacity
        size: 11
        color: Qt.rgba(1, 1, 1, 0.5)
    }
    ShellText
    {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        anchors.bottomMargin: 10 - wallpapersContent.chromeOffset
        width: parent.width - 48
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        label: wallpapersContent.applying ? Tr.tr("wallpapers.applying") : wallpapersContent.scanError || wallpapersContent.applyError
        opacity: wallpapersContent.chromeOpacity
        color: wallpapersContent.applying ? Qt.rgba(1, 1, 1, 0.8) : "#ff8c8c"
        size: 11
    }
    Column
    {
        visible: wallpapersContent.images.length === 0
        anchors.centerIn: parent
        anchors.verticalCenterOffset: wallpapersContent.chromeOffset
        width: parent.width - 64
        spacing: 12
        opacity: wallpapersContent.fluid ? Motion.contentOpacity(wallpapersContent.reveal) : 1
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
