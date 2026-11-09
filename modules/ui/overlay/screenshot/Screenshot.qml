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

    Glide on progress { duration: Theme.animationDurationOpen }
    Component.onCompleted: Qt.callLater(() => { progress = 1; forceActiveFocus(); })
    Keys.onEscapePressed: ServiceScreenshot.cancel()
    Keys.onReturnPressed: submit()
    Keys.onEnterPressed: submit()

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
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24 - 12 * (1 - screenshot.progress)
        width: modes.implicitWidth + 16
        height: modes.height + 12
        radius: 18
        color: Theme.colorSolid
        opacity: screenshot.progress

        SettingsChoices
        {
            id: modes
            objectName: "screenshotModes"
            anchors.centerIn: parent
            options: [{label: Tr.tr("screenshot.area"), value: Enums.ScreenshotArea}, {label: Tr.tr("screenshot.screen"), value: Enums.ScreenshotScreen}]
            current: selection.mode
            enabled: !ServiceScreenshot.working
            onSelected: value => Config.set("screenshotMode", value)
        }
    }

    Rectangle
    {
        visible: selection.valid
        x: Math.max(12, Math.min(screenshot.width - width - 12, selection.region.x))
        y: Math.max(84, Math.min(screenshot.height - 140, selection.region.y - 32))
        width: Math.min(information.implicitWidth + 20, screenshot.width - 24)
        height: 26
        radius: 8
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

    Column
    {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height - 24 + 12 * (1 - screenshot.progress)
        spacing: 10
        opacity: screenshot.progress

        Rectangle
        {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(520, screenshot.width - 48)
            height: hint.implicitHeight + 14
            radius: 10
            color: Theme.colorSolid
            ShellText
            {
                id: hint
                x: 12; y: 7
                width: parent.width - 24
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                color: ServiceScreenshot.error ? Theme.colorCritical : Theme.text2
                label: ServiceScreenshot.error || Tr.tr(ServiceScreenshot.working ? "screenshot.working" : selection.mode === Enums.ScreenshotArea ? "screenshot.areaHint" : "screenshot.screenHint")
            }
        }
        Rectangle
        {
            anchors.horizontalCenter: parent.horizontalCenter
            width: actions.implicitWidth + 24
            height: actions.height + 16
            radius: 18
            color: Theme.colorSolid

            Row
            {
                id: actions
                anchors.centerIn: parent
                spacing: 10

                SettingsChoices
                {
                    objectName: "screenshotDestination"
                    anchors.verticalCenter: parent.verticalCenter
                    options: [{label: Tr.tr("screenshot.copy"), value: false}, {label: Tr.tr("screenshot.save"), value: true}]
                    current: Config.screenshotSave
                    enabled: !ServiceScreenshot.working
                    onSelected: value => Config.set("screenshotSave", value)
                }
                ActionButton
                {
                    objectName: "screenshotConfirm"
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.tr("screenshot.capture")
                    enabled: screenshot.ready && selection.valid && !ServiceScreenshot.working
                    onClicked: screenshot.submit()
                }
                ActionButton
                {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.tr("common.cancel")
                    icon: Icon.close
                    iconOnly: true
                    onClicked: ServiceScreenshot.cancel()
                }
            }
        }
    }
}
