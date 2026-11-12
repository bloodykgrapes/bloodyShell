import QtQuick

import "../../../animations"
import "../../../core"

Item
{
    id: widgetSlot

    property int side: 0
    property string widgetID: ""
    property var    prevSlot: null
    property var    nextSlot: null
    property real   spacing: 0

    property bool compact: false
    property bool animate: true
    property bool vertical: false
    property bool expandCross: false

    readonly property var    widgetMeta: Registry.widgets[widgetID]
    readonly property Item widget: loader.item
    readonly property rect contentRect: Qt.rect(content.x, content.y, content.width, content.height)

    readonly property bool allowed: !vertical || !widgetMeta || widgetMeta.vertical !== false

    readonly property bool shown: loader.item
        ? allowed && loader.item.active && !(compact && !!widgetMeta && widgetMeta.collapse === true)
        : false

    readonly property real gap: prevSlot ? Math.max(0, Theme.barSpacing - spacing) : 0
    readonly property real lead: 0
    readonly property real trail: 0

    readonly property real contentSize: Math.ceil(vertical ? loader.height : loader.width)

    readonly property real span: shown ? gap + lead + contentSize + trail : 0
    readonly property real baseCross: vertical ? Theme.barVerticalWidth : Theme.barGroupThickness
    readonly property real crossSize: expandCross && shown ? Math.max(baseCross, vertical ? loader.width : loader.height) : baseCross
    width:  vertical ? crossSize : span
    height: vertical ? span : crossSize

    readonly property bool settled: Math.abs((vertical ? height : width) - span) < 0.5
        && Math.abs((vertical ? width : height) - crossSize) < 0.5

    visible: shown || (vertical ? height : width) > 0.5

    opacity: shown ? 1 : 0
    enabled: shown

    Glide on width { enabled: Config.animationsEnabled && widgetSlot.animate }
    Glide on height { enabled: Config.animationsEnabled && widgetSlot.animate }
    Smooth on opacity { enabled: Config.animationsEnabled && widgetSlot.animate; duration: Theme.animationDurationBar * 0.7 }

    Component.onCompleted: if (!widgetMeta) console.warn("Bar: unknown widget " + widgetID)

    Item
    {
        id: content
        x: widgetSlot.vertical ? 0 : widgetSlot.gap + widgetSlot.lead
        y: widgetSlot.vertical ? widgetSlot.gap + widgetSlot.lead : 0
        width:  widgetSlot.vertical ? widgetSlot.width : Math.max(0, widgetSlot.width - widgetSlot.gap - widgetSlot.lead - widgetSlot.trail)
        height: widgetSlot.vertical ? Math.max(0, widgetSlot.height - widgetSlot.gap - widgetSlot.lead - widgetSlot.trail) : widgetSlot.height
        clip: !widgetSlot.settled

        Loader
        {
            id: loader
            source: widgetSlot.allowed && widgetSlot.widgetMeta ? widgetSlot.widgetMeta.url : ""

            x: widgetSlot.vertical ? Math.round((widgetSlot.width - width) / 2) : 0
            y: widgetSlot.vertical ? 0 : Math.round((widgetSlot.height - height) / 2)

            width:  item ? item.implicitWidth  : 0
            height: item ? item.implicitHeight : 0
        }
        Binding
        {
            target: loader.item
            property: "side"
            value: widgetSlot.side
            when: loader.status === Loader.Ready
        }

    }
}
