pragma ComponentBehavior: Bound

import QtQuick

import "../../../animations"
import "../../../animations/OverlayMotion.js" as Motion
import "../../../common"
import "../../../core"
import "../../../services"
import "../settings/components"

FocusScope
{
    id: screenshot

    readonly property var capture: ServiceScreenshot.capture
    readonly property alias selectionItem: selection
    readonly property bool ready: background.status === Image.Ready
    readonly property rect pixels: ServiceScreenshot.pixels(selection.region, width, height)
    property bool mounted: false
    property real progress: mounted && ready ? 1 : 0
    readonly property bool fluid: Config.animationsFluid
    readonly property real toolbarProgress: fluid ? Motion.phase(progress, 0.18, 0.90) : progress
    readonly property real margin: Math.max(8, Math.min(24, height * 0.04))

    Ease on progress
    {
        duration: screenshot.fluid ? Motion.fluidOpenDuration : Theme.animationDurationOpen
        curve: screenshot.fluid ? Motion.fluidOpenCurve : Theme.easingEmphasized
    }
    Component.onCompleted: Qt.callLater(() =>
    {
        screenshot.mounted = true;
        screenshot.forceActiveFocus();
    })
    Keys.onEscapePressed: ServiceScreenshot.cancel()
    Keys.onReturnPressed: submit()
    Keys.onEnterPressed: submit()
    Keys.onPressed: event =>
    {
        if (ServiceScreenshot.working || !ready) return;
        const step = event.modifiers & Qt.ShiftModifier ? 10 : 1;
        let dx = 0, dy = 0;
        if (event.key === Qt.Key_Left) dx = -step;
        else if (event.key === Qt.Key_Right) dx = step;
        else if (event.key === Qt.Key_Up) dy = -step;
        else if (event.key === Qt.Key_Down) dy = step;
        else return;
        selection.nudge(dx, dy, !!(event.modifiers & Qt.ControlModifier));
        event.accepted = true;
    }

    function submit()
    {
        if (ready && selection.valid) ServiceScreenshot.submit(selection.region, width, height);
    }

    Image
    {
        id: background
        objectName: "screenshotBackground"
        anchors.fill: parent
        source: screenshot.capture ? screenshot.capture.image : ""
        fillMode: Image.Stretch
        cache: false
        onStatusChanged: if (status === Image.Error) ServiceScreenshot.cancel()
    }
    CaptureSelection
    {
        id: selection
        objectName: "screenshotSelection"
        anchors.fill: parent
        enabled: screenshot.ready && !ServiceScreenshot.working
        shadeOpacity: screenshot.fluid ? Motion.phase(screenshot.progress, 0, 0.60) : 1
        mode: Config.screenshotMode === Enums.ScreenshotScreen ? Enums.ScreenshotScreen : Enums.ScreenshotArea
        onSelected: if (Config.screenshotsInstantly) screenshot.submit()
    }

    ShellText
    {
        anchors.centerIn: parent
        width: parent.width - screenshot.margin * 2
        horizontalAlignment: Text.AlignHCenter
        label: Tr.tr("screenshot.selectArea")
        visible: screenshot.ready && selection.mode === Enums.ScreenshotArea && !selection.valid && !selection.dragging
        opacity: screenshot.toolbarProgress
        color: Qt.rgba(1, 1, 1, 0.92)
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.65)
        size: 13
        font.weight: Font.Medium
    }

    Rectangle
    {
        id: dimensions
        objectName: "screenshotDimensions"
        readonly property real gap: 10
        readonly property real above: selection.region.y - height - gap
        readonly property real below: selection.region.y + selection.region.height + gap
        readonly property real minimumY: screenshot.margin + toolbar.height + gap
        readonly property real maximumY: screenshot.height - height - gap
        readonly property real preferredY: above >= minimumY ? above : below <= maximumY ? below : selection.region.y + gap

        visible: selection.valid && selection.mode === Enums.ScreenshotArea
        x: Math.max(gap, Math.min(screenshot.width - width - gap, selection.region.x + (selection.region.width - width) / 2))
        y: Math.min(maximumY, Math.max(minimumY, preferredY))
        width: Math.min(information.implicitWidth + 20, screenshot.width - gap * 2)
        height: 26
        radius: height / 2
        color: Theme.colorSolid

        ShellText
        {
            id: information
            anchors.centerIn: parent
            width: parent.width - 20
            label: screenshot.pixels.width + " × " + screenshot.pixels.height
            textFormat: Text.PlainText
            color: Theme.text1
            size: 11
            font.family: Theme.fontMono
        }
    }

    SurfaceShadow { surface: toolbar; cornerRadius: toolbar.radius; opacity: toolbar.opacity }

    ShellSurface
    {
        id: toolbar
        objectName: "screenshotToolbar"
        readonly property real inset: 8
        readonly property real idealWidth: modes.implicitWidth + destination.implicitWidth + actions.implicitWidth + controls.spacing * 2

        anchors.horizontalCenter: parent.horizontalCenter
        y: screenshot.margin - 14 * (1 - screenshot.toolbarProgress)
        width: Math.min(idealWidth + inset * 2, screenshot.width - screenshot.margin * 2)
        height: contents.height + inset * 2
        radius: Theme.radiusLarge
        baseColor: Theme.popupColorBackground
        materialEnabled: !ShellMaterial.blur
        opacity: screenshot.toolbarProgress
        enabled: opacity > 0

        MouseArea { anchors.fill: parent }
        Column
        {
            id: contents
            x: toolbar.inset
            y: toolbar.inset
            width: toolbar.width - toolbar.inset * 2
            spacing: 6

            Flow
            {
                id: controls
                width: parent.width
                spacing: 8

                SettingsChoices
                {
                    id: modes
                    objectName: "screenshotModes"
                    width: Math.min(implicitWidth, controls.width)
                    options: [{label: Tr.tr("screenshot.area"), value: Enums.ScreenshotArea}, {label: Tr.tr("screenshot.screen"), value: Enums.ScreenshotScreen}]
                    current: selection.mode
                    enabled: !ServiceScreenshot.working
                    onSelected: value => Config.set("screenshotMode", value)
                }
                SettingsChoices
                {
                    id: destination
                    objectName: "screenshotDestination"
                    width: Math.min(implicitWidth, controls.width)
                    options: [{label: Tr.tr("screenshot.copy"), value: "copy"}, {label: Tr.tr("screenshot.save"), value: "save"}]
                    current: Config.screenshotsAction
                    enabled: !ServiceScreenshot.working
                    onSelected: value => Config.set("screenshotsAction", value)
                }
                Row
                {
                    id: actions
                    spacing: 6

                    Button
                    {
                        objectName: "screenshotConfirm"
                        text: Tr.tr("screenshot.capture")
                        icon: Icon.screenshot
                        iconOnly: screenshot.width < 440
                        primary: true
                        hoverScale: 1
                        enabled: screenshot.ready && selection.valid && !ServiceScreenshot.working
                        onClicked: screenshot.submit()
                    }
                    Button
                    {
                        objectName: "screenshotCancel"
                        text: Tr.tr("common.cancel")
                        icon: Icon.close
                        iconOnly: true
                        hoverScale: 1
                        onClicked: ServiceScreenshot.cancel()
                    }
                }
            }

            ShellText
            {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                color: ServiceScreenshot.error ? Theme.colorCritical : Theme.text2
                label: ServiceScreenshot.error || (ServiceScreenshot.working ? Tr.tr("screenshot.working") : "")
            }
        }
    }
}
