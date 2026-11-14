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

    property string kind: "frame"
    property int value: 0
    property string label: ""
    property bool current: false
    signal clicked()

    readonly property bool themeStyle: kind === "theme"
    readonly property bool menu: kind === "menu"
    readonly property bool frameStyle: kind === "frame"
    readonly property bool equalizerStyle: kind === "equalizer"
    readonly property bool animationStyle: kind === "animation"
    readonly property bool framed: frameStyle || themeStyle
    readonly property bool sceneLight: themeStyle ? value === Enums.ThemeLight : Theme.light
    readonly property var scenePalette: Theme.styles[sceneLight ? Enums.ThemeLight : Enums.ThemeDark]
    readonly property color sceneInk: Theme.textFor(sceneLight)
    readonly property color sceneAccent: Theme.accentShell ? Theme.accentFor(sceneLight) : sceneInk
    readonly property color sceneMuted: Qt.rgba(sceneInk.r, sceneInk.g, sceneInk.b, sceneLight ? 0.50 : 0.65)
    readonly property color sceneLine: Qt.rgba(sceneInk.r, sceneInk.g, sceneInk.b, sceneLight ? 0.22 : 0.30)
    readonly property color sceneFrame: Qt.tint(Theme.frameFor(sceneLight), Theme.accentShell ? Qt.rgba(sceneAccent.r, sceneAccent.g, sceneAccent.b, sceneLight ? 0.06 : 0.10) : "transparent")
    readonly property color scenePanel: Qt.tint(scenePalette[2], Qt.rgba(sceneInk.r, sceneInk.g, sceneInk.b, sceneLight ? 0 : 0.04))
    readonly property color sceneDesktop: Qt.tint(scenePalette[1], Qt.rgba(sceneInk.r, sceneInk.g, sceneInk.b, sceneLight ? 0.12 : 0.30))
    readonly property color sceneSoftAccent: Qt.rgba(sceneAccent.r, sceneAccent.g, sceneAccent.b, Theme.accentShell ? 0.65 : 0.38)
    readonly property int sceneStyle: themeStyle ? Config.barType : value
    readonly property bool inFrame: framed && sceneStyle === Enums.InFrame
    readonly property bool islands: framed && sceneStyle === Enums.Islands
    readonly property bool filled: framed && sceneStyle === Enums.Filled
    readonly property bool menuFloating: menu && value === Enums.MenuFloating
    readonly property rect popRect: Qt.rect(width - 16 - 66, menuFloating ? 32 : 25, 66, menuFloating ? 46 : 52)

    readonly property bool previewing: (animationStyle || equalizerStyle) && activity.active && (hovered || visualFocus)
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

    component PreviewPanel: Rectangle
    {
        color: settingsStyleCard.scenePanel
        border.width: 1
        border.color: settingsStyleCard.sceneLine
    }

    ClippingRectangle
    {
        id: preview
        objectName: "stylePreview"
        width: parent.width
        height: Math.round(width * 0.62)
        radius: Theme.radiusLarge
        color: settingsStyleCard.sceneDesktop

        FrameSurface
        {
            anchors.fill: parent
            objectName: settingsStyleCard.menu ? "previewMenuSurface" : "previewBarSurface"
            visible: settingsStyleCard.framed || settingsStyleCard.menu
            thickness: settingsStyleCard.framed ? 6 : 0
            cornerRadius: 10
            bodyRadius: 9
            smoothing: 8
            panelSmoothing: settingsStyleCard.menu && !settingsStyleCard.menuFloating ? smoothing : 0
            startBody: settingsStyleCard.menu ? Qt.rect(8, 8, width - 16, 18) : Qt.rect(0, 0, 0, 0)
            centerBody: settingsStyleCard.filled ? Qt.rect(-9, -9, width + 18, 37)
                : settingsStyleCard.inFrame ? Qt.rect((width - 68) / 2, 6, 68, 22)
                : settingsStyleCard.islands ? Qt.rect((width - 68) / 2, 12, 68, 22) : Qt.rect(0, 0, 0, 0)
            centerPanel: settingsStyleCard.menu ? settingsStyleCard.popRect : Qt.rect(0, 0, 0, 0)
            fillColor: settingsStyleCard.sceneFrame
            borderWidth: 1
            borderColor: settingsStyleCard.sceneLine
        }
        Row
        {
            visible: settingsStyleCard.framed
            anchors.horizontalCenter: parent.horizontalCenter
            y: settingsStyleCard.islands ? 17 : 11
            spacing: 5
            Rectangle { width: 12; height: 12; radius: 4; color: settingsStyleCard.sceneAccent }
            Column
            {
                spacing: 3
                Rectangle { width: 32; height: 4; radius: 2; color: settingsStyleCard.sceneInk; opacity: 0.8 }
                Rectangle { width: 22; height: 3; radius: 1.5; color: settingsStyleCard.sceneMuted }
            }
        }
        PreviewPanel
        {
            visible: settingsStyleCard.animationStyle
            x: 8; y: 8
            width: parent.width - 16; height: 12
            radius: 6
            color: settingsStyleCard.sceneFrame
        }
        Item
        {
            visible: settingsStyleCard.menu || settingsStyleCard.animationStyle
            x: 8; y: 8
            width: parent.width - 16; height: settingsStyleCard.menu ? 18 : 12
            Rectangle { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 4; radius: 2; color: settingsStyleCard.sceneSoftAccent }
            Rectangle
            {
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                width: 20; height: 3; radius: 1.5
                color: settingsStyleCard.sceneMuted
            }
        }
        Item
        {
            visible: settingsStyleCard.menu
            x: settingsStyleCard.popRect.x; y: settingsStyleCard.popRect.y
            width: settingsStyleCard.popRect.width; height: settingsStyleCard.popRect.height
            Column
            {
                x: 10; y: 12
                spacing: 7
                Repeater
                {
                    model: [40, 30, 36]
                    Rectangle { required property var modelData; width: modelData; height: 4; radius: 2; color: settingsStyleCard.sceneMuted }
                }
            }
        }
        PreviewPanel
        {
            visible: settingsStyleCard.framed
            x: 16; y: 38
            width: parent.width - 32; height: Math.max(20, parent.height - 60)
            radius: 6
            Column
            {
                x: 7; y: 7
                spacing: 4
                Rectangle { width: 30; height: 3; radius: 1.5; color: settingsStyleCard.sceneMuted }
                Rectangle { width: 21; height: 3; radius: 1.5; color: settingsStyleCard.sceneLine }
            }
            Rectangle
            {
                anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                width: 17; height: 9; radius: 4.5
                color: settingsStyleCard.sceneAccent
                Rectangle { anchors { right: parent.right; rightMargin: 1.5; verticalCenter: parent.verticalCenter } width: 6; height: 6; radius: 3; color: settingsStyleCard.scenePanel }
            }
        }
        PreviewPanel
        {
            visible: settingsStyleCard.themeStyle
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
            width: 58; height: 10; radius: 5
            color: settingsStyleCard.sceneFrame
            Row
            {
                anchors.centerIn: parent
                spacing: 5
                Repeater { model: 3; Rectangle { required property int index; width: 6; height: 6; radius: 2; color: index === 0 ? settingsStyleCard.sceneAccent : settingsStyleCard.sceneMuted } }
            }
        }
        Loader
        {
            anchors.fill: parent
            active: settingsStyleCard.equalizerStyle
            sourceComponent: Item
            {
                id: equalizerPreview
                objectName: "equalizerStylePreview"
                property real phase: 0
                FrameAnimation
                {
                    running: settingsStyleCard.previewing
                    onTriggered: equalizerPreview.phase = (equalizerPreview.phase + Math.min(frameTime, 0.05) * Math.PI * 2 / 2.4) % (Math.PI * 2)
                }
                Equalizer
                {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                    height: parent.height * 0.65
                    style: settingsStyleCard.value
                    bars: 16
                    spacing: 3
                    radius: 2
                    minimumHeight: 0
                    active: settingsStyleCard.previewing
                    animated: true
                    topColor: Theme.accentShell ? Theme.accentAlpha(0.35) : Theme.inkAlpha(0.35)
                    bottomColor: Theme.colorAccent
                    samples:
                    {
                        const values = [];
                        for (let i = 0; i < 16; i++)
                            values.push(0.15 + 0.7 * (0.5 + 0.5 * Math.sin(i * 0.7 + equalizerPreview.phase)) * (0.65 + 0.35 * Math.cos(i * 0.35 - equalizerPreview.phase)));
                        return values;
                    }
                }
            }
        }
        Loader
        {
            anchors.fill: parent
            active: settingsStyleCard.animationStyle
            sourceComponent: Item
            {
                id: animationPreview
                objectName: "animationStylePreview"
                readonly property bool minimal: settingsStyleCard.value === Enums.AnimationsDisabled
                readonly property bool fluid: settingsStyleCard.value === Enums.AnimationsFluid
                readonly property real reveal: settingsStyleCard.previewing ? progress : 1
                property real progress: 1

                PreviewPanel
                {
                    objectName: "animationPreviewPanel"
                    width: parent.width * 0.62
                    height: parent.height * 0.56
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2 + 8 + (animationPreview.minimal ? 0 : 18 * (1 - animationPreview.reveal))
                    radius: 9
                    opacity: Math.max(0, Math.min(1, animationPreview.reveal))
                    scale: animationPreview.fluid ? 0.82 + 0.18 * animationPreview.reveal : 1
                    Row
                    {
                        x: 9; y: 9; spacing: 5
                        Repeater { model: 3; Rectangle { width: 4; height: 4; radius: 2; color: settingsStyleCard.sceneMuted } }
                    }
                    Rectangle { x: 9; y: 22; width: parent.width * 0.6; height: 3; radius: 1.5; color: settingsStyleCard.sceneMuted }
                    Rectangle
                    {
                        x: 9; y: parent.height - height - 8
                        width: parent.width - 18; height: 8; radius: 4
                        color: settingsStyleCard.sceneLine
                        Rectangle { width: parent.width * 0.6; height: parent.height; radius: 4; color: settingsStyleCard.sceneSoftAccent }
                    }
                }
                SequentialAnimation
                {
                    running: settingsStyleCard.previewing
                    loops: Animation.Infinite

                    PropertyAction { target: animationPreview; property: "progress"; value: 0 }
                    PauseAnimation { duration: 200 }
                    NumberAnimation
                    {
                        target: animationPreview; property: "progress"; from: 0; to: 1
                        duration: animationPreview.minimal ? 0 : animationPreview.fluid ? 460 : 220
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: animationPreview.fluid ? [0.18, 1.5, 0.35, 1.0, 1.0, 1.0] : [0.2, 0.0, 0.2, 1.0, 1.0, 1.0]
                    }
                    PauseAnimation { duration: 850 }
                    NumberAnimation
                    {
                        target: animationPreview; property: "progress"; from: 1; to: 0
                        duration: animationPreview.minimal ? 0 : animationPreview.fluid ? 190 : 140
                        easing.type: Easing.InCubic
                    }
                    PauseAnimation { duration: 350 }
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
