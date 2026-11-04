import QtQuick

import ".."
import "../../core"

Rectangle
{
    id: settingsTile

    required property Item row
    property bool hovered: false

    readonly property var  siblings: row.parent ? row.parent.children : []
    readonly property bool first:
    {
        for (const c of siblings) { if (c === row) return true; if (c.visible && c.height > 0) return false; }
        return true;
    }
    readonly property bool last:
    {
        for (let i = siblings.length - 1; i >= 0; i--) { const c = siblings[i]; if (c === row) return true; if (c.visible && c.height > 0) return false; }
        return true;
    }

    readonly property real outer: Theme.radiusLarge + 2
    readonly property real inner: 0

    anchors.fill: parent
    topLeftRadius:     first ? outer : inner
    topRightRadius:    first ? outer : inner
    bottomLeftRadius:  last ? outer : inner
    bottomRightRadius: last ? outer : inner
    color: Theme.settingsColorCard

    Rectangle
    {
        anchors.fill: parent
        topLeftRadius:     parent.topLeftRadius
        topRightRadius:    parent.topRightRadius
        bottomLeftRadius:  parent.bottomLeftRadius
        bottomRightRadius: parent.bottomRightRadius
        color: Theme.colorHover
        opacity: settingsTile.hovered ? 1 : 0
        Smooth on opacity {}
    }
}
