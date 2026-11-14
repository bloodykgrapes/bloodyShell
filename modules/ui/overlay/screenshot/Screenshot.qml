pragma ComponentBehavior: Bound

import QtQuick

import "../../../animations"
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
    property real progress: 0
    readonly property real margin: Math.max(8, Math.min(24, height * 0.04))

    Glide on progress { duration: Theme.animationDurationOpen }
    Component.onCompleted: Qt.callLater(() => { progress = 1; forceActiveFocus(); })
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
        mode: Config.screenshotMode === Enums.ScreenshotScreen ? Enums.ScreenshotScreen : Enums.ScreenshotArea
    }

    Rectangle
    {
        id: modePanel
        objectName: "screenshotModePanel"
        anchors.horizontalCenter: parent.horizontalCenter
        y: screenshot.margin - 12 * (1 - screenshot.progress)
        width: Math.min(modes.implicitWidth + 20, screenshot.width - screenshot.margin * 2)
        height: modes.height + 16
        radius: 20
        color: Theme.colorSolid
        border.width: 1
        border.color: Theme.colorHairline
        opacity: screenshot.progress

        MouseArea { anchors.fill: parent }
        SettingsChoices
        {
            id: modes
            objectName: "screenshotModes"
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 20)
            options: [{label: Tr.tr("screenshot.area"), value: Enums.ScreenshotArea}, {label: Tr.tr("screenshot.screen"), value: Enums.ScreenshotScreen}]
            current: selection.mode
            enabled: !ServiceScreenshot.working
            onSelected: value => Config.set("screenshotMode", value)
        }
    }

    Rectangle
    {
        objectName: "screenshotDimensions"
        readonly property real above: selection.region.y - height - 10
        readonly property real minimumY: modePanel.y + modePanel.height + 10
        visible: selection.valid && selection.mode === Enums.ScreenshotArea
        x: Math.max(12, Math.min(screenshot.width - width - 12, selection.region.x))
        y: Math.max(minimumY, Math.min(controls.y - height - 10, above >= minimumY ? above : selection.region.y + 12))
        width: Math.min(information.implicitWidth + 20, screenshot.width - 24)
        height: 30
        radius: 10
        color: Theme.colorSolid
        border.width: 1
        border.color: Theme.colorHairline
        ShellText
        {
            id: information
            anchors.centerIn: parent
            width: parent.width - 20
            label: screenshot.pixels.width + " × " + screenshot.pixels.height
            textFormat: Text.PlainText
            color: Theme.text1
            size: 12
            font.family: Theme.fontMono
        }
    }

    Rectangle
    {
        id: controls
        objectName: "screenshotToolbar"
        readonly property bool compact: width < destination.implicitWidth + actions.implicitWidth + 48
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height - screenshot.margin + 12 * (1 - screenshot.progress)
        width: Math.min(Math.max(480, destination.implicitWidth + actions.implicitWidth + 48), screenshot.width - screenshot.margin * 2)
        height: hint.implicitHeight + 54 + actionArea.height
        radius: 22
        color: Theme.colorSolid
        border.width: 1
        border.color: Theme.colorHairline
        opacity: screenshot.progress

        MouseArea { anchors.fill: parent }
        ShellText
        {
            id: hint
            x: 18; y: 14
            width: parent.width - 36
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            color: ServiceScreenshot.error ? Theme.colorCritical : Theme.text2
            label: ServiceScreenshot.error || Tr.tr(ServiceScreenshot.working ? "screenshot.working" : selection.mode === Enums.ScreenshotArea ? "screenshot.areaHint" : "screenshot.screenHint")
        }
        Rectangle
        {
            x: 18; y: hint.y + hint.implicitHeight + 12
            width: parent.width - 36
            height: 1
            color: Theme.colorHairline
        }
        Item
        {
            id: actionArea
            x: 14; y: hint.y + hint.implicitHeight + 25
            width: parent.width - 28
            height: controls.compact ? destination.height + actions.height + 10 : Math.max(destination.height, actions.height)

            SettingsChoices
            {
                id: destination
                objectName: "screenshotDestination"
                x: controls.compact ? (parent.width - width) / 2 : 0
                y: controls.compact ? 0 : (parent.height - height) / 2
                width: Math.min(implicitWidth, parent.width)
                options: [{label: Tr.tr("screenshot.copy"), value: false}, {label: Tr.tr("screenshot.save"), value: true}]
                current: Config.screenshotSave
                enabled: !ServiceScreenshot.working
                onSelected: value => Config.set("screenshotSave", value)
            }
            Row
            {
                id: actions
                x: controls.compact ? (parent.width - width) / 2 : parent.width - width
                y: controls.compact ? destination.height + 10 : (parent.height - height) / 2
                spacing: 8

                ActionButton
                {
                    objectName: "screenshotConfirm"
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.tr("screenshot.capture")
                    icon: Icon.check
                    height: destination.height
                    color: Theme.colorSelection
                    hoverScale: 1
                    enabled: screenshot.ready && selection.valid && !ServiceScreenshot.working
                    onClicked: screenshot.submit()
                }
                ActionButton
                {
                    objectName: "screenshotCancel"
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.tr("common.cancel")
                    icon: Icon.close
                    iconOnly: true
                    width: destination.height
                    height: destination.height
                    onClicked: ServiceScreenshot.cancel()
                }
            }
        }
    }
}
