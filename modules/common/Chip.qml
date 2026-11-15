import QtQuick

import "../core"

Rectangle
{
    property string text: ""
    property color  tint: "transparent"
    readonly property bool tinted: tint.a > 0

    width: chipText.implicitWidth + 14
    height: chipText.implicitHeight + 6
    radius: height / 2
    color: tinted ? Qt.rgba(tint.r, tint.g, tint.b, 0.16) : Theme.colorField

    ShellText
    {
        id: chipText
        anchors.centerIn: parent
        label: parent.text
        size: 10
        color: parent.tinted ? parent.tint : Theme.text2
    }
}
