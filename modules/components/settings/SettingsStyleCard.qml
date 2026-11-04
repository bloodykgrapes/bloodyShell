import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

import ".."
import "../../core"

Item
{
    id: settingsStyleCard

    property string kind: "bar"
    property int    value: 0
    property string label: ""
    property bool   current: false
    signal clicked()

    readonly property bool big:        kind === "background"
    readonly property bool bar:        kind === "bar"
    readonly property bool dock:       kind === "dock"
    readonly property bool menu:       kind === "menu"
    readonly property int  background: big ? value : 0

    readonly property bool barDocked:   bar && value <= Enums.BarFrame
    readonly property bool barFrame:    bar && value === Enums.BarFrame
    readonly property bool barFloating: bar && value === Enums.BarFloating
    readonly property bool barIslands:  bar && value === Enums.BarIslands
    readonly property bool dockDefault: dock && value === Enums.DockAttached

    readonly property bool menuFloating: menu && value === Enums.MenuFloating
    readonly property bool popFloating:  menuFloating
    readonly property rect popRect:      menu ? Qt.rect(width - 16 - 66, menuFloating ? 31 : 25, 66, menuFloating ? 46 : 52) : Qt.rect(0, 0, 0, 0)

    readonly property real barY:   big ? preview.height * 0.3 + 17 : barDocked ? 11 : menu ? 17 : 16
    readonly property real barPad: big ? 26 : barDocked ? 12 : 16

    width: 150
    height: preview.height + 22

    scale: area.pressed ? 0.96 : area.containsMouse ? 1.03 : 1
    Spring on scale {}

    ClippingRectangle
    {
        id: preview

        width: parent.width
        height: Math.round(width * (settingsStyleCard.big || settingsStyleCard.menu ? 0.62 : 0.36))
        radius: Theme.radiusLarge

        Item
        {
            id: screen
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true

            Item
            {
                id: scene
                anchors.fill: parent
                layer.enabled: true

                Rectangle { anchors.fill: parent; color: "#575757" }
                Rectangle
                {
                    visible: settingsStyleCard.big
                    x: parent.width * 0.52; y: parent.height * 0.12
                    width: parent.height * 0.62; height: width; radius: width / 2
                    color: "#f2b86b"
                }
            }

            component Shape: ShaderEffect
            {
                property color fill: "white"
                property color edge: "transparent"

                anchors.fill: parent

                property size     size:        Qt.size(width, height)
                property vector4d inner:       settingsStyleCard.barFrame ? Qt.vector4d(5, 22, 5, 5)
                                             : settingsStyleCard.barDocked ? Qt.vector4d(-60, 22, -60, -60)
                                             : settingsStyleCard.dockDefault ? Qt.vector4d(-60, -60, -60, 0)
                                             : Qt.vector4d(-60, -60, -60, -60)
                property real innerRadius: settingsStyleCard.barFrame ? 10 : 0

                property rect island0: settingsStyleCard.big ? Qt.rect(12, height * 0.3, width - 24, 34)
                                     : settingsStyleCard.barIslands ? Qt.rect(8, 7, width * 0.26, 18)
                                     : settingsStyleCard.barFloating ? Qt.rect(7, 7, width - 14, 18)
                                     : settingsStyleCard.dock ? Qt.rect(width / 2 - 34, settingsStyleCard.dockDefault ? height - 22 : height - 28, 68, settingsStyleCard.dockDefault ? 22 : 20)
                                     : settingsStyleCard.menu ? Qt.rect(9, 8, width - 18, 18)
                                     : Qt.rect(0, 0, 0, 0)
                property rect island1: settingsStyleCard.barIslands ? Qt.rect(width / 2 - 20, 7, 40, 18) : Qt.rect(0, 0, 0, 0)
                property rect island2: settingsStyleCard.barIslands ? Qt.rect(width - 8 - width * 0.22, 7, width * 0.22, 18) : Qt.rect(0, 0, 0, 0)
                property real islandRadius: settingsStyleCard.big ? 17 : 9

                property rect panel0: settingsStyleCard.popRect
                property rect panel1: Qt.rect(0, 0, 0, 0)
                property rect panel2: Qt.rect(0, 0, 0, 0)
                property real panelRadius: 8

                property real smoothing:      settingsStyleCard.barFrame || settingsStyleCard.dockDefault ? 8 : 0
                property real panelSmoothing: settingsStyleCard.popFloating ? 2 : 8

                property real  borderWidth: edge.a > 0 ? 1 : 0
                property color fillColor:   fill
                property color borderColor: edge
                property rect  cut:         Qt.rect(0, 0, 0, 0)

                fragmentShader: Qt.resolvedUrl("../../../assets/shaders/bar.frag.qsb")
            }

            Shape { id: mask; visible: false; layer.enabled: true }
            MultiEffect
            {
                visible: settingsStyleCard.background === Enums.BackgroundBlur
                anchors.fill: parent
                source: scene
                blurEnabled: true
                blur: 1
                blurMax: 32
                autoPaddingEnabled: false
                maskEnabled: true
                maskSource: mask
            }

            Shape
            {
                readonly property real alpha: settingsStyleCard.background === Enums.BackgroundSolid ? 1 : settingsStyleCard.background === Enums.BackgroundBlur ? Theme.blurAlpha : Theme.transparentAlpha
                fill: Qt.rgba(Theme.colorSolid.r, Theme.colorSolid.g, Theme.colorSolid.b, Theme.light && settingsStyleCard.background !== Enums.BackgroundSolid ? alpha + 0.1 : alpha)
                edge: settingsStyleCard.background === Enums.BackgroundSolid ? Theme.colorLine : Theme.glassEdge
            }

            readonly property bool marks: !settingsStyleCard.dock
            Rectangle
            {
                visible: screen.marks
                x: settingsStyleCard.barPad; y: settingsStyleCard.barY - height / 2
                width: settingsStyleCard.big ? 18 : 12; height: settingsStyleCard.big ? 8 : 5; radius: height / 2
                color: Config.themeAccent ? Theme.accentBase : Theme.text1
            }
            Rectangle
            {
                visible: screen.marks
                x: screen.width - width - settingsStyleCard.barPad; y: settingsStyleCard.barY - height / 2
                width: settingsStyleCard.big ? 30 : 20; height: settingsStyleCard.big ? 6 : 4; radius: height / 2
                color: Theme.text3
            }

            Row
            {
                visible: settingsStyleCard.dock
                spacing: 6
                x: (screen.width - width) / 2
                y: screen.height - (settingsStyleCard.dockDefault ? 11 : 18) - height / 2
                Repeater
                {
                    model: 4
                    Rectangle { required property int index; width: 8; height: 8; radius: 3; color: index === 0 && Config.themeAccent ? Theme.accentBase : Theme.text3 }
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
        }
    }

    Rectangle
    {
        anchors.fill: preview
        radius: preview.radius
        color: "transparent"
        border.width: settingsStyleCard.current ? 2 : 1
        border.color: settingsStyleCard.current ? Theme.text1 : Theme.colorLine
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
}
