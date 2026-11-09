pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

import "../../../../animations"
import "../../../../common"
import "../../../../core"
import "../../../frame"

Item
{
    id: settingsStyleCard

    property string kind: "frame"
    property int    value: 0
    property string label: ""
    property bool   current: false
    signal clicked()

    readonly property bool menu:       kind === "menu"
    readonly property bool frameStyle: kind === "frame"
    readonly property bool equalizerStyle: kind === "equalizer"
    readonly property bool animationStyle: kind === "animation"
    readonly property bool inFrame:    value === Enums.InFrame
    readonly property bool islands:    frameStyle && value === Enums.Islands
    readonly property bool filled:     frameStyle && value === Enums.Filled

    readonly property bool menuFloating: menu && value === Enums.MenuFloating
    readonly property bool popFloating:  menuFloating
    readonly property rect popRect:      menu ? Qt.rect(width - 16 - 66, menuFloating ? 31 : 25, 66, menuFloating ? 46 : 52) : Qt.rect(0, 0, 0, 0)

    readonly property bool previewing: (animationStyle || equalizerStyle) && activity.active && (area.containsMouse || activeFocus)
    RenderActivity { id: activity; target: settingsStyleCard }

    width: 150
    height: preview.height + 22
    activeFocusOnTab: true
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    scale: area.pressed ? 0.96 : area.containsMouse ? 1.03 : 1
    Spring on scale {}

    ClippingRectangle
    {
        id: preview

        width: parent.width
        height: Math.round(width * 0.62)
        radius: Theme.radiusLarge

        Item
        {
            id: screen
            anchors.fill: parent
            layer.enabled: !settingsStyleCard.animationStyle && !settingsStyleCard.equalizerStyle
            layer.smooth: true

            Rectangle { anchors.fill: parent; color: (settingsStyleCard.animationStyle || settingsStyleCard.equalizerStyle) ? Theme.style[1] : "#575757" }

            ShaderEffect
            {
                visible: settingsStyleCard.menu
                property color fill: Theme.frameColor
                property color edge: Theme.colorLine

                anchors.fill: parent

                property size     size:        Qt.size(width, height)
                property vector4d inner:       Qt.vector4d(-60, -60, -60, -60)
                property real innerRadius: 0

                property rect island0: Qt.rect(9, 8, width - 18, 18)
                property rect island1: Qt.rect(0, 0, 0, 0)
                property rect island2: Qt.rect(0, 0, 0, 0)
                property real islandRadius: 9

                property rect panel0: settingsStyleCard.popRect
                property rect panel1: Qt.rect(0, 0, 0, 0)
                property rect panel2: Qt.rect(0, 0, 0, 0)
                property real panelRadius: 8

                property real smoothing:      0
                property real panelSmoothing: settingsStyleCard.popFloating ? 2 : 8

                property real  borderWidth: edge.a > 0 ? 1 : 0
                property color fillColor:   fill
                property color borderColor: edge
                property rect  cut:         Qt.rect(0, 0, 0, 0)

                fragmentShader: Qt.resolvedUrl("../../../../../assets/shaders/bar.frag.qsb")
            }

            FrameSurface
            {
                anchors.fill: parent
                visible: settingsStyleCard.frameStyle
                thickness: 6
                cornerRadius: 10
                bodyRadius: 9
                smoothing: 8
                centerBody: settingsStyleCard.filled ? Qt.rect(-9, -9, screen.width + 18, 37)
                    : settingsStyleCard.inFrame ? Qt.rect(screen.width / 2 - 34, 6, 68, 22) : Qt.rect(0, 0, 0, 0)
            }

            Rectangle
            {
                visible: settingsStyleCard.islands
                x: screen.width / 2 - width / 2
                y: 12
                width: Math.min(68, screen.width - 16)
                height: 22
                radius: 9
                color: Theme.frameColor
            }

            Rectangle
            {
                visible: settingsStyleCard.menu
                x: 16; y: 17 - height / 2
                width: 12; height: 5; radius: height / 2
                color: Config.themeAccent ? Theme.accentBase : Theme.text1
            }
            Rectangle
            {
                visible: settingsStyleCard.menu
                x: screen.width - width - 16; y: 17 - height / 2
                width: 20; height: 4; radius: height / 2
                color: Theme.text3
            }

            Row
            {
                visible: settingsStyleCard.frameStyle
                anchors.horizontalCenter: parent.horizontalCenter
                y: settingsStyleCard.islands ? 17 : 11
                spacing: 5
                Rectangle { width: 12; height: 12; radius: 4; color: Theme.text1 }
                Column
                {
                    spacing: 3
                    Rectangle { width: 32; height: 4; radius: 2; color: Theme.text1 }
                    Rectangle { width: 22; height: 3; radius: 1.5; color: Theme.text3 }
                }
            }

            Column
            {
                visible: settingsStyleCard.menu
                x: settingsStyleCard.popRect.x + 10
                y: settingsStyleCard.popRect.y + (settingsStyleCard.menuFloating ? 10 : 14)
                spacing: 7
                Repeater
                {
                    model: [40, 30, 36]
                    Rectangle { required property var modelData; width: modelData; height: 4; radius: 2; color: Theme.text3 }
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

                    readonly property bool minimal: settingsStyleCard.value === Enums.AnimationsDisabled
                    readonly property bool fluid: settingsStyleCard.value === Enums.AnimationsFluid
                    readonly property real reveal: settingsStyleCard.previewing ? progress : 1
                    property real progress: 1

                    Rectangle
                    {
                        x: 8; y: 8
                        width: parent.width - 16; height: 12; radius: 6
                        color: Theme.colorRaised
                        Rectangle { x: 5; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 4; radius: 2; color: Theme.colorAccent }
                        Rectangle
                        {
                            anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
                            width: 20; height: 3; radius: 1.5
                            color: Theme.text3
                        }
                    }

                    Rectangle
                    {
                        width: parent.width * 0.62
                        height: parent.height * 0.56
                        x: (parent.width - width) / 2
                        y: (parent.height - height) / 2 + 8 + (animationPreview.minimal ? 0 : 18 * (1 - animationPreview.reveal))
                        radius: 9
                        color: Theme.colorRaised
                        border.width: 1
                        border.color: Theme.colorLine
                        opacity: Math.max(0, Math.min(1, animationPreview.reveal))
                        scale: animationPreview.fluid ? 0.82 + 0.18 * animationPreview.reveal : 1

                        Row
                        {
                            x: 9; y: 9
                            spacing: 5
                            Repeater
                            {
                                model: 3
                                Rectangle { width: 4; height: 4; radius: 2; color: Theme.text3 }
                            }
                        }
                        Rectangle { x: 9; y: 22; width: parent.width * 0.6; height: 3; radius: 1.5; color: Theme.text2 }
                        Rectangle
                        {
                            x: 9; y: parent.height - height - 8
                            width: parent.width - 18; height: 8; radius: 4
                            color: Theme.colorField
                            Rectangle { width: parent.width * 0.6; height: parent.height; radius: 4; color: Theme.colorAccent }
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
    }

    Rectangle
    {
        anchors.fill: preview
        radius: preview.radius
        color: "transparent"
        border.width: settingsStyleCard.current ? 2 : 1
        border.color: settingsStyleCard.current || settingsStyleCard.activeFocus ? Theme.text1 : Theme.colorLine
        Tint on border.color {}
    }

    ShellText
    {
        anchors { horizontalCenter: parent.horizontalCenter; top: preview.bottom; topMargin: 6 }
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
        onClicked: settingsStyleCard.clicked()
    }

    Accessible.role: Accessible.RadioButton
    Accessible.name: settingsStyleCard.label
    Accessible.checked: settingsStyleCard.current
    Accessible.onPressAction: clicked()
}
