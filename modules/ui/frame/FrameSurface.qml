import QtQuick

import "../../core"

ShaderEffect
{
    property real thickness: Theme.frameThickness
    property rect startBody: Qt.rect(0, 0, 0, 0)
    property rect centerBody: Qt.rect(0, 0, 0, 0)
    property rect endBody: Qt.rect(0, 0, 0, 0)
    property rect startPanel: Qt.rect(0, 0, 0, 0)
    property rect centerPanel: Qt.rect(0, 0, 0, 0)
    property rect endPanel: Qt.rect(0, 0, 0, 0)
    property rect dockBody: Qt.rect(0, 0, 0, 0)
    property rect leftBody: Qt.rect(0, 0, 0, 0)
    property rect rightBody: Qt.rect(0, 0, 0, 0)

    readonly property vector2d screenSize: Qt.vector2d(width, height)
    property real cornerRadius: Theme.frameRadius
    property real bodyRadius: Theme.barRadius
    property real smoothing: Theme.frameSmoothing
    readonly property real panelSmoothing: Config.barMenu === Enums.MenuFloating ? 0 : Theme.frameSmoothing
    property color fillColor: Theme.frameColor

    fragmentShader: Qt.resolvedUrl("../../../assets/shaders/frame.frag.qsb")
}
