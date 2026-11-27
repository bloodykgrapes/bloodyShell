pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

import "../../../../animations"
import "../../../../common"
import "../../../../common" as Common
import "../../../../core"
import "../../../frame"

Common.InteractiveControl
{
    id: settingsStyleCard

    required property string kind
    property int value: 0
    property string label: ""
    property bool current: false
    signal clicked()

    readonly property bool themeStyle: kind === "theme"
    readonly property bool launcherStyle: kind === "launcher"
    readonly property bool equalizerStyle: kind === "equalizer"
    readonly property bool animationStyle: kind === "animation"
    readonly property bool automaticTheme: themeStyle && value === Enums.ThemeAuto
    readonly property bool sceneLight: Theme.light
    readonly property var scenePalette: Theme.styles[sceneLight ? Enums.ThemeLight : Enums.ThemeDark]
    readonly property color sceneInk: Theme.textFor(sceneLight)
    readonly property color sceneAccent: Theme.accentShell ? Theme.accentFor(sceneLight) : sceneInk
    readonly property color sceneMuted: Qt.rgba(sceneInk.r, sceneInk.g, sceneInk.b, sceneLight ? 0.50 : 0.65)
    readonly property color sceneLine: Qt.rgba(sceneInk.r, sceneInk.g, sceneInk.b, sceneLight ? 0.22 : 0.30)
    readonly property color sceneFrame: Qt.tint(Theme.frameFor(sceneLight), Theme.accentShell ? Qt.rgba(sceneAccent.r, sceneAccent.g, sceneAccent.b, sceneLight ? 0.06 : 0.10) : "transparent")
    readonly property color scenePanel: Qt.tint(scenePalette[2], Qt.rgba(sceneInk.r, sceneInk.g, sceneInk.b, sceneLight ? 0 : 0.04))
    readonly property color sceneDesktop: Qt.tint(scenePalette[1], Qt.rgba(sceneInk.r, sceneInk.g, sceneInk.b, sceneLight ? 0.12 : 0.30))
    readonly property var sampleColors: ({
        canvas: scenePalette[1], frame: sceneFrame, panel: scenePanel, outline: sceneLine,
        ink: sceneInk, muted: sceneMuted, accent: sceneAccent
    })
    readonly property bool previewing: animationStyle && activity.active && (hovered || visualFocus)
    RenderActivity { id: activity; target: settingsStyleCard }

    implicitWidth: 150
    width: parent ? Math.min(implicitWidth, parent.width) : implicitWidth
    height: preview.height + caption.implicitHeight + 8
    activeFocusOnTab: true
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }

    scale: area.pressed ? 0.96 : hovered ? 1.03 : 1
    Spring on scale {}

    component DesktopPreview: Rectangle
    {
        id: desktopPreview

        required property bool lightMode
        readonly property color sceneInk: Theme.textFor(lightMode)
        readonly property color sceneAccent: Theme.accentShell ? Theme.accentFor(lightMode) : sceneInk
        readonly property color sceneMuted: Qt.rgba(sceneInk.r, sceneInk.g, sceneInk.b, lightMode ? 0.50 : 0.65)
        readonly property color sceneLine: Qt.rgba(sceneInk.r, sceneInk.g, sceneInk.b, lightMode ? 0.22 : 0.30)
        readonly property color sceneFrame: Theme.frameFor(lightMode)
        readonly property color scenePanel: Theme.styles[lightMode ? Enums.ThemeLight : Enums.ThemeDark][2]

        color: Theme.styles[lightMode ? Enums.ThemeLight : Enums.ThemeDark][1]

        FrameSurface
        {
            anchors.fill: parent
            objectName: "previewBarSurface"
            thickness: 6
            cornerRadius: 10
            readonly property real barWidth: Math.min(68, width * 0.68)
            centerBody: Qt.rect((width - barWidth) / 2, 6, barWidth, 22)
            fillColor: desktopPreview.sceneFrame
            borderWidth: 1
            borderColor: desktopPreview.sceneLine
        }
        Row
        {
            visible: settingsStyleCard.themeStyle
            anchors.horizontalCenter: parent.horizontalCenter
            y: 11
            spacing: 5
            Rectangle { width: 12; height: 12; radius: 4; color: desktopPreview.sceneAccent }
            Column
            {
                spacing: 3
                Rectangle { width: 32; height: 4; radius: 2; color: desktopPreview.sceneInk; opacity: 0.8 }
                Rectangle { width: 22; height: 3; radius: 1.5; color: desktopPreview.sceneMuted }
            }
        }
        Rectangle
        {
            visible: settingsStyleCard.themeStyle
            border.color: desktopPreview.sceneLine
            x: 16; y: Math.round(parent.height * 0.41)
            width: Math.max(0, parent.width - 32)
            height: Math.max(0, parent.height - y - 12)
            radius: 6
            color: desktopPreview.scenePanel
            Column
            {
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                width: Math.max(0, parent.width - 40)
                spacing: 4
                Rectangle { width: Math.min(30, parent.width); height: 3; radius: 1.5; color: desktopPreview.sceneMuted }
                Rectangle { width: Math.min(21, parent.width * 0.7); height: 3; radius: 1.5; color: desktopPreview.sceneLine }
            }
            Rectangle
            {
                anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                width: 17; height: 9; radius: 4.5
                color: desktopPreview.sceneAccent
                Rectangle { anchors { right: parent.right; rightMargin: 1.5; verticalCenter: parent.verticalCenter } width: 6; height: 6; radius: 3; color: desktopPreview.scenePanel }
            }
        }
    }

    ClippingRectangle
    {
        id: preview
        objectName: "stylePreview"
        width: parent.width
        height: Math.round(width * 0.62)
        radius: Theme.radiusLarge
        color: settingsStyleCard.animationStyle ? settingsStyleCard.scenePalette[1] : settingsStyleCard.sceneDesktop

        Loader
        {
            anchors.fill: parent
            active: settingsStyleCard.themeStyle
            sourceComponent: Item
            {
                id: desktopScene
                Repeater
                {
                    model: settingsStyleCard.automaticTheme ? 2 : 1
                    Item
                    {
                        id: half
                        required property int index
                        objectName: settingsStyleCard.automaticTheme ? (index === 0 ? "autoLightHalf" : "autoDarkHalf") : ""
                        x: index === 0 ? 0 : Math.floor(desktopScene.width / 2)
                        width: settingsStyleCard.automaticTheme && index === 0 ? Math.floor(desktopScene.width / 2) : desktopScene.width - x
                        height: desktopScene.height
                        clip: settingsStyleCard.automaticTheme

                        DesktopPreview
                        {
                            x: -half.x
                            width: desktopScene.width
                            height: desktopScene.height
                            lightMode: settingsStyleCard.automaticTheme ? half.index === 0
                                : settingsStyleCard.themeStyle ? settingsStyleCard.value === Enums.ThemeLight : Theme.light
                        }
                    }
                }
            }
        }
        Loader
        {
            anchors.fill: parent
            active: settingsStyleCard.equalizerStyle
            sourceComponent: Item
            {
                objectName: "equalizerStylePreview"
                Equalizer
                {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                    height: parent.height * 0.65
                    style: settingsStyleCard.value
                    bars: 16
                    spacing: 3
                    radius: 2
                    minimumHeight: 0
                    active: false
                    animated: false
                    topColor: Theme.accentShell ? Theme.accentAlpha(0.35) : Theme.inkAlpha(0.35)
                    bottomColor: Theme.colorAccent
                    samples:
                    {
                        const values = [];
                        for (let i = 0; i < 16; i++)
                            values.push(0.15 + 0.7 * (0.5 + 0.5 * Math.sin(i * 0.7)) * (0.65 + 0.35 * Math.cos(i * 0.35)));
                        return values;
                    }
                }
            }
        }
        Loader
        {
            anchors.fill: parent
            active: settingsStyleCard.animationStyle
            sourceComponent: SettingsAnimationPreview
            {
                mode: settingsStyleCard.value
                playing: settingsStyleCard.previewing
                colors: settingsStyleCard.sampleColors
            }
        }
        Loader
        {
            anchors.fill: parent
            active: settingsStyleCard.launcherStyle
            sourceComponent: Item
            {
                Rectangle
                {
                    anchors { fill: parent; margins: 12 }
                    radius: 9
                    color: settingsStyleCard.sceneDesktop
                }
                Rectangle
                {
                    x: parent.width * 0.12
                    y: parent.height * 0.27
                    width: parent.width * 0.76
                    height: parent.height * 0.48
                    radius: settingsStyleCard.value === Enums.LauncherIsland ? 10 : 13
                    color: settingsStyleCard.scenePanel
                    border.width: 1
                    border.color: settingsStyleCard.sceneLine
                }
                Rectangle
                {
                    x: parent.width * 0.18
                    y: parent.height * 0.38
                    width: parent.width * 0.64
                    height: 16
                    radius: 6
                    color: settingsStyleCard.value === Enums.LauncherIsland
                        ? settingsStyleCard.sceneFrame : settingsStyleCard.sceneMuted
                    opacity: 0.8
                }
                Repeater
                {
                    model: 3
                    Rectangle
                    {
                        required property int index
                        x: parent.width * (0.22 + index * 0.2)
                        y: parent.height * 0.63
                        width: 14
                        height: 14
                        radius: 5
                        color: index === 0 ? settingsStyleCard.sceneAccent : settingsStyleCard.sceneMuted
                    }
                }
            }
        }
    }

    Rectangle
    {
        anchors.fill: preview
        radius: preview.radius
        color: "transparent"
        border.width: settingsStyleCard.current ? 2 : 1
        border.color: settingsStyleCard.current || settingsStyleCard.visualFocus ? Theme.text1 : Theme.colorLine
        Tint on border.color {}
    }

    ShellText
    {
        id: caption
        anchors { horizontalCenter: parent.horizontalCenter; top: preview.bottom; topMargin: 6 }
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        label: settingsStyleCard.label
        size: 11
        color: settingsStyleCard.current ? Theme.text1 : Theme.text3
        Tint on color {}
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: settingsStyleCard.focusFor(Qt.MouseFocusReason)
        onClicked: settingsStyleCard.clicked()
    }

    Accessible.role: Accessible.RadioButton
    Accessible.name: settingsStyleCard.label
    Accessible.checked: settingsStyleCard.current
    Accessible.onPressAction: if (enabled) clicked()
}
