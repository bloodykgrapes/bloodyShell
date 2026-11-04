import QtQuick

ShaderEffect
{
    property var source
    property color tint: "white"

    fragmentShader: Qt.resolvedUrl("../../assets/shaders/monochrome.frag.qsb")
}
