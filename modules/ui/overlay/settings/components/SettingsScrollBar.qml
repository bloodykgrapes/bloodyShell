import QtQuick
import QtQuick.Controls.Basic as Controls

import "../../../../animations"
import "../../../../core"

Controls.ScrollBar
{
    id: scrollBar

    required property Flickable view
    property bool compact: false

    width: 12
    anchors.right: parent.right
    anchors.rightMargin: compact ? 1 : 4
    z: 20
    padding: 0
    topPadding: compact ? 4 : 12
    bottomPadding: topPadding
    minimumSize: Math.min(1, 28 / Math.max(1, availableHeight))
    policy: Controls.ScrollBar.AsNeeded
    visible: policy === Controls.ScrollBar.AlwaysOn || (policy === Controls.ScrollBar.AsNeeded && size < 1)
    hoverEnabled: true
    active: view.moving || hovered || pressed

    background: Item
    {
        Rectangle
        {
            anchors.horizontalCenter: parent.horizontalCenter
            y: scrollBar.topPadding
            width: 6
            height: scrollBar.availableHeight
            radius: width / 2
            color: Theme.colorField
            opacity: scrollBar.hovered || scrollBar.pressed ? 1 : 0

            Smooth on opacity {}
        }
    }

    contentItem: Item
    {
        implicitWidth: 12
        implicitHeight: 28

        Rectangle
        {
            anchors.centerIn: parent
            width: scrollBar.pressed ? 6 : scrollBar.hovered ? 5 : 3
            height: parent.height
            radius: width / 2
            color: scrollBar.pressed ? Theme.text1 : Theme.text3
            opacity: scrollBar.pressed ? 0.95 : scrollBar.active ? 0.75 : 0.4

            Smooth on width {}
            Smooth on opacity {}
            Tint on color {}
        }
    }
}
