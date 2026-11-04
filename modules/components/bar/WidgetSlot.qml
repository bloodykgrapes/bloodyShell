import QtQuick

import ".."
import "../../core"

Item
{
    id: widgetSlot

    property string widgetID: ""
    property var    prevSlot: null
    property var    nextSlot: null
    property real   spacing: 0

    property bool compact: false
    property bool animate: true
    property bool vertical: false

    readonly property var    widgetMeta: Registry.widgets[widgetID]

    readonly property bool allowed: !vertical || !widgetMeta || widgetMeta.vertical !== false

    readonly property bool shown: loader.item
        ? allowed && loader.item.active && !(compact && !!widgetMeta && widgetMeta.collapse === true)
        : false

    readonly property bool highlighted: Config.barHighlight.indexOf(widgetID) >= 0
    readonly property bool joinPrev:    highlighted && !!prevSlot && prevSlot.highlighted
    readonly property bool joinNext:    highlighted && !!nextSlot && nextSlot.highlighted

    readonly property real gap: !!prevSlot && !joinPrev ? Math.max(0, Theme.barSpacing - spacing) : 0

    readonly property real lead:  highlighted && !joinPrev ? Theme.barGroupPadding : 0
    readonly property real trail: highlighted && !joinNext ? Theme.barGroupPadding : 0

    readonly property real contentSize: Math.ceil(vertical ? loader.height : loader.width)

    readonly property real span: shown ? gap + lead + contentSize + trail : 0
    width:  vertical ? Theme.barVerticalWidth : span
    height: vertical ? span : Theme.barGroupThickness

    readonly property bool settled: Math.abs((vertical ? height : width) - span) < 0.5

    visible: shown || (vertical ? height : width) > 0.5

    opacity: shown ? 1 : 0
    enabled: shown

    Glide on width { enabled: Config.animationsEnabled && widgetSlot.animate }
    Glide on height { enabled: Config.animationsEnabled && widgetSlot.animate }
    Smooth on opacity { enabled: Config.animationsEnabled && widgetSlot.animate; duration: Theme.animationDurationBar * 0.7 }

    Component.onCompleted: if (!widgetMeta) console.warn("Bar: unknown widget " + widgetID)

    readonly property bool runHead: highlighted && !joinPrev
    readonly property real runEnd: joinNext && nextSlot ? nextSlot.runEnd : (vertical ? y + height : x + width)

    Rectangle
    {
        visible: widgetSlot.runHead && length > 0.5

        readonly property real thickness: Theme.barGroupThickness
        readonly property real length: widgetSlot.runEnd - (widgetSlot.vertical ? widgetSlot.y : widgetSlot.x) - widgetSlot.gap

        x: widgetSlot.vertical ? Math.round((widgetSlot.width - thickness) / 2) : widgetSlot.gap
        y: widgetSlot.vertical ? widgetSlot.gap : Math.round((widgetSlot.height - thickness) / 2)
        width:  widgetSlot.vertical ? thickness : length
        height: widgetSlot.vertical ? length : thickness

        radius: Math.min(Theme.barGroupRadius, Math.min(width, height) / 2)
        color: Theme.barColorGroup
    }

    Item
    {
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
    }
}
