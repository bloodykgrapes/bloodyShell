import QtQuick

import "../../../../common"
import "../../../../core"

Item
{
    id: heading

    property string title: ""
    property bool centered: false
    property real topPadding: 0
    property real bottomPadding: 0

    readonly property real gap: centered ? 8 : 12

    width: parent ? parent.width : 400
    implicitHeight: topPadding + label.implicitHeight + bottomPadding
    height: implicitHeight
    visible: title !== ""

    Rectangle
    {
        width: Math.max(0, label.x - heading.gap)
        height: 1
        y: heading.topPadding + Math.floor(label.height / 2)
        color: Theme.colorPanelEdge
    }
    ShellText
    {
        id: label

        x: heading.centered ? (heading.width - width) / 2 : Math.min(20, heading.width * 0.1) + heading.gap
        y: heading.topPadding
        width: Math.min(implicitWidth, Math.max(0, heading.width - (heading.centered ? 24 : 44) - heading.gap * 2))
        label: heading.title
        size: heading.centered ? 10 : 14
        color: heading.centered ? Theme.text3 : Theme.text1
        font.weight: Font.DemiBold
        font.letterSpacing: heading.centered ? 0.8 : 0
        horizontalAlignment: heading.centered ? Text.AlignHCenter : Text.AlignLeft
        wrapMode: Text.Wrap
    }
    Rectangle
    {
        x: label.x + label.width + heading.gap
        width: Math.max(0, heading.width - x)
        height: 1
        y: heading.topPadding + Math.floor(label.height / 2)
        color: Theme.colorPanelEdge
    }
}
