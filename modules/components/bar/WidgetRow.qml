import QtQuick

Grid
{
    id: widgetRow

    property var  widgets: []
    property bool compact: false
    property bool animate: true
    property bool vertical: false

    property var slots: []

    function neighbor(index, dir)
    {
        for (let i = index + dir; i >= 0 && i < slots.length; i += dir)
            if (slots[i] && slots[i].shown) return slots[i];
        return null;
    }

    columns: vertical ? 1 : 1000

    spacing: 2

    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    Repeater
    {
        id: repeater
        model: widgetRow.widgets

        onItemAdded: (index, item) =>
        {
            const list = widgetRow.slots.slice();
            list[index] = item;
            widgetRow.slots = list;
        }
        onItemRemoved: (index, item) =>
        {
            const list = widgetRow.slots.slice();
            if (list[index] === item) list[index] = null;
            widgetRow.slots = list;
        }

        WidgetSlot
        {
            required property int    index
            required property string modelData

            widgetID: modelData
            prevSlot: widgetRow.neighbor(index, -1)
            nextSlot: widgetRow.neighbor(index, 1)
            spacing: widgetRow.spacing
            compact: widgetRow.compact
            animate: widgetRow.animate
            vertical: widgetRow.vertical
        }
    }
}
