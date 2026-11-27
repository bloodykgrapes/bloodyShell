import QtQuick

import "../../../../common"
import "../../../../core"

Item
{
    id: heading

    property string title: ""
    property string summary: ""
    property bool centered: false
    property real topPadding: 0
    property real bottomPadding: 0

    width: parent ? parent.width : 400
    implicitHeight: topPadding + Math.max(label.implicitHeight, summaryLabel.implicitHeight) + bottomPadding
    height: implicitHeight
    visible: title !== ""

    ShellText
    {
        id: label

        y: heading.topPadding
        width: Math.max(0, heading.width - (summaryLabel.visible ? summaryLabel.implicitWidth + 12 : 0))
        label: heading.title
        size: heading.centered ? 10 : 16
        color: heading.centered ? Theme.text3 : Theme.text1
        font.weight: Font.DemiBold
        font.letterSpacing: heading.centered ? 0.8 : 0
        wrapMode: Text.Wrap
    }

    ShellText
    {
        id: summaryLabel
        anchors { right: parent.right; top: parent.top; topMargin: heading.topPadding }
        label: heading.summary
        size: 12
        color: Theme.text3
        visible: heading.summary !== ""
    }
}
