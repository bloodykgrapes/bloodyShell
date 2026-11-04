import QtQuick

import ".."
import "../../core"

Item
{
    id: disclosure

    property alias title: header.title
    property alias description: header.description
    property alias icon: header.icon
    property alias summary: header.summary
    property bool expanded: false
    default property alias content: body.data

    width: parent ? parent.width : 400
    implicitHeight: header.height + viewport.height
    height: implicitHeight

    SettingsDisclosureHeader
    {
        id: header
        width: parent.width
        height: implicitHeight
        expanded: disclosure.expanded
        onToggled: expanded => disclosure.expanded = expanded
    }

    Item
    {
        id: viewport
        y: header.height
        width: parent.width
        height: (body.implicitHeight + 10) * reveal
        clip: true
        visible: disclosure.expanded || reveal > 0.001

        property real reveal: disclosure.expanded ? 1 : 0
        Ease on reveal { duration: Theme.animationDurationControl }

        Rectangle
        {
            x: 8
            y: 10
            width: 2
            height: Math.max(0, body.implicitHeight - 4)
            radius: 1
            color: Theme.colorLine
            opacity: viewport.reveal * 0.5
        }

        Column
        {
            id: body
            x: 20
            y: 10 + (Config.animationsFluid ? (1 - viewport.reveal) * -8 : 0)
            width: parent.width - x
            spacing: 2
            enabled: disclosure.expanded
            opacity: viewport.reveal
        }
    }
}
