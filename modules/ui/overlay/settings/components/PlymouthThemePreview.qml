pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"

Rectangle
{
    id: preview

    required property var artwork
    required property bool loadArtwork
    readonly property bool showComposition: loadArtwork && screenshot.status !== Image.Ready
    readonly property bool textTheme: ["details", "text", "tribar"].includes(artwork.kind)
    readonly property var splashProgress: artwork.progress || null
    readonly property color backgroundTop: artwork.top || artwork.bottom || "#101014"
    readonly property color backgroundBottom: artwork.bottom || backgroundTop

    objectName: "plymouthPreview"
    width: parent.width
    height: Math.round(width * 9 / 16)
    radius: Theme.radiusMedium
    gradient: Gradient
    {
        GradientStop { position: 0; color: preview.backgroundTop }
        GradientStop { position: 1; color: preview.backgroundBottom }
    }
    clip: true

    PreviewImage
    {
        id: screenshot
        objectName: "plymouthThemeImage"
        anchors.fill: parent
        anchors.margins: 3
        source: preview.loadArtwork ? preview.artwork.image || "" : ""
    }
    PreviewImage
    {
        id: background
        anchors.fill: parent
        anchors.margins: 3
        source: preview.showComposition ? preview.artwork.background || "" : ""
        fillMode: Image.PreserveAspectCrop
        clip: true
    }
    PreviewImage
    {
        id: firmware
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) * 0.36
        width: parent.width * 0.49
        height: parent.height * 0.46
        source: preview.showComposition ? preview.artwork.firmwareImage || "" : ""
    }
    ShellText
    {
        anchors.centerIn: firmware
        visible: preview.showComposition && preview.artwork.firmware === true
            && (firmware.status === Image.Null || firmware.status === Image.Error)
        label: Tr.tr("settings.plymouth.firmwareLogo")
        color: "#b7b7c1"
        size: 11
    }
    PreviewImage
    {
        id: sun
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9
        source: preview.showComposition && preview.artwork.kind === "space-flares" ? preview.artwork.star || "" : ""
    }
    Repeater
    {
        model: preview.showComposition && preview.artwork.kind === "fade-throbber"
            ? [[0.14, 0.31], [0.22, 0.70], [0.39, 0.16], [0.63, 0.76], [0.72, 0.25], [0.84, 0.56]] : []
        PreviewImage
        {
            required property var modelData
            x: (preview.width - width) * modelData[0]
            y: (preview.height - height) * modelData[1]
            width: 11
            height: width
            source: preview.artwork.star || ""
        }
    }
    PreviewImage
    {
        id: emblem
        x: (parent.width - width) * (preview.artwork.logoX ?? 0.5)
        y: (parent.height - height) * (preview.artwork.logoY ?? 0.5)
        width: parent.width * (preview.artwork.logoY > 0.85 ? 0.32 : 0.46)
        height: parent.height * (preview.artwork.logoY > 0.85 ? 0.17 : 0.32)
        source: preview.showComposition ? preview.artwork.logo || "" : ""
    }
    PreviewImage
    {
        id: frame
        x: (parent.width - width) * (preview.artwork.frameX ?? 0.5)
        y: (parent.height - height) * (preview.artwork.frameY ?? 0.5)
        width: parent.width * 0.32
        height: parent.height * 0.22
        source: preview.showComposition ? preview.artwork.frame || "" : ""
    }
    Rectangle
    {
        visible: preview.showComposition && preview.splashProgress !== null
        x: (parent.width - width) * (preview.splashProgress?.x ?? 0.5)
        y: (parent.height - height) * (preview.splashProgress?.y ?? 0.8)
        width: Math.round(parent.width * (preview.splashProgress?.width ?? 0))
        height: Math.max(2, Math.round(parent.height * (preview.splashProgress?.height ?? 0)))
        color: preview.splashProgress?.track || "transparent"

        Rectangle
        {
            width: Math.round(parent.width * 0.58)
            height: parent.height
            color: preview.splashProgress?.fill || "transparent"
        }
    }
    Column
    {
        visible: preview.showComposition && preview.textTheme
        width: parent.width - 20
        x: 10
        y: preview.artwork.kind === "details" ? 12 : parent.height - height - 12
        spacing: 5

        ShellText
        {
            width: parent.width
            label: preview.artwork.kind === "details" ? "[  OK  ]  " + Tr.tr("settings.plymouth.booting")
                : preview.artwork.system || ""
            font.family: "monospace"
            size: 10
            color: preview.artwork.kind === "details" ? "#b0d9a6" : "#dedee6"
            wrapMode: preview.artwork.kind === "details" ? Text.Wrap : Text.NoWrap
        }
        Row
        {
            id: progress
            readonly property bool stepped: preview.artwork.kind === "text"

            visible: preview.artwork.kind !== "details"
            width: parent.width
            height: stepped ? 6 : 4
            spacing: stepped ? 3 : 0
            Repeater
            {
                model: progress.stepped ? 9 : 3
                Rectangle
                {
                    required property int index
                    width: (progress.width - (progress.stepped ? 8 * progress.spacing : 0)) / (progress.stepped ? 9 : 3)
                    height: parent.height
                    color: progress.stepped ? (index < 6 ? "#b4d9f5" : "#41414b")
                        : ["#0071bd", "#52acf2", "#d6edff"][index]
                }
            }
        }
    }
    ShellText
    {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 20)
        visible: preview.loadArtwork && !preview.textTheme && !preview.splashProgress && !preview.artwork.firmware && !preview.artwork.top
            && !preview.artwork.bottom && !preview.artwork.star
            && [screenshot, background, emblem, frame].every(image => image.status === Image.Null || image.status === Image.Error)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        size: 11
        color: "#b7b7c1"
        label: Tr.tr("settings.plymouth.noPreview")
    }
    component PreviewImage: Image
    {
        sourceSize.width: Math.ceil(width * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }
}
