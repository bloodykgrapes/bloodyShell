import QtQuick

import ".."
import "../../core"
import "../../services"

Item
{
    id: settingsDisplayLayout

    property string selected: ""
    signal picked(string name)

    width: 520
    height: 220

    readonly property var screens: ServiceDisplay.outputs.filter(o => o.logical).map(o => ({
        name: o.name, x: o.logical.x, y: o.logical.y, w: o.logical.width, h: o.logical.height,
        label: o.name, detail: o.current_mode !== null && o.modes[o.current_mode] ? o.modes[o.current_mode].width + " × " + o.modes[o.current_mode].height : ""
    }))

    readonly property real pad: 18
    property var frame: fit(screens)
    function fit(list)
    {
        if (list.length === 0) return { s: 1, ox: 0, oy: 0 };
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (const m of list) { x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y); x1 = Math.max(x1, m.x + m.w); y1 = Math.max(y1, m.y + m.h) }

        const s = Math.min((width - pad * 2) / ((x1 - x0) * 1.6), (height - pad * 2) / ((y1 - y0) * 1.6));
        return { s: s, ox: width / 2 - (x0 + x1) / 2 * s, oy: height / 2 - (y0 + y1) / 2 * s };
    }
    property bool dragging: false

    property var moved: ({})
    onScreensChanged: { moved = {}; if (!dragging) frame = fit(screens) }

    function snap(name, x, y, w, h)
    {
        const others = screens.filter(m => m.name !== name);
        if (others.length === 0) return { x: Math.round(x), y: Math.round(y) };
        const near = 0.12;
        let best = null, bestD = Infinity;
        for (const r of others)
        {
            const alignY = v => { for (const t of [r.y, r.y + r.h - h, r.y + (r.h - h) / 2]) if (Math.abs(v - t) < h * near) return t; return Math.max(r.y - h + 1, Math.min(r.y + r.h - 1, v)) };
            const alignX = v => { for (const t of [r.x, r.x + r.w - w, r.x + (r.w - w) / 2]) if (Math.abs(v - t) < w * near) return t; return Math.max(r.x - w + 1, Math.min(r.x + r.w - 1, v)) };
            const options = [
                { x: r.x - w,   y: alignY(y) },
                { x: r.x + r.w, y: alignY(y) },
                { x: alignX(x), y: r.y - h },
                { x: alignX(x), y: r.y + r.h },
            ];
            for (const o of options)
            {
                const d = Math.hypot(o.x - x, o.y - y);
                if (d < bestD) { bestD = d; best = o; }
            }
        }
        return { x: Math.round(best.x), y: Math.round(best.y) };
    }

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Theme.colorField
    }

    Repeater
    {
        model: settingsDisplayLayout.screens

        Rectangle
        {
            id: tile

            required property var modelData
            readonly property bool current: modelData.name === settingsDisplayLayout.selected

            property real dragX: 0
            property real dragY: 0
            readonly property var at: settingsDisplayLayout.moved[modelData.name] || modelData
            x: area.drag.active ? dragX : settingsDisplayLayout.frame.ox + at.x * settingsDisplayLayout.frame.s
            y: area.drag.active ? dragY : settingsDisplayLayout.frame.oy + at.y * settingsDisplayLayout.frame.s
            width: Math.max(24, modelData.w * settingsDisplayLayout.frame.s)
            height: Math.max(16, modelData.h * settingsDisplayLayout.frame.s)
            z: area.drag.active ? 2 : current ? 1 : 0

            radius: Theme.radiusMedium
            color: current ? Theme.colorSelection : Theme.colorHover
            border.width: current ? 2 : 1
            border.color: current ? Theme.colorAccent : Theme.colorLine
            Tint on color {}
            Behavior on x { enabled: Config.animationsEnabled && !area.drag.active; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: Config.animationsEnabled && !area.drag.active; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Column
            {
                anchors.centerIn: parent
                spacing: 2
                ShellText { anchors.horizontalCenter: parent.horizontalCenter; label: tile.modelData.label; size: 12; color: Theme.text1; font.weight: Font.DemiBold }
                ShellText { anchors.horizontalCenter: parent.horizontalCenter; label: tile.modelData.detail; size: 10; color: Theme.text3 }
            }

            MouseArea
            {
                id: area
                anchors.fill: parent
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                drag.target: settingsDisplayLayout.screens.length > 1 ? dragProxy : null
                drag.threshold: 4

                onPressed:
                {
                    settingsDisplayLayout.picked(tile.modelData.name);
                    dragProxy.x = tile.x;
                    dragProxy.y = tile.y;
                    tile.dragX = tile.x;
                    tile.dragY = tile.y;
                }
                drag.onActiveChanged:
                {
                    if (drag.active) { settingsDisplayLayout.dragging = true; return; }

                    const s = settingsDisplayLayout.frame.s;
                    const p = settingsDisplayLayout.snap(tile.modelData.name, (tile.dragX - settingsDisplayLayout.frame.ox) / s, (tile.dragY - settingsDisplayLayout.frame.oy) / s, tile.modelData.w, tile.modelData.h);
                    settingsDisplayLayout.dragging = false;
                    if (p.x !== tile.modelData.x || p.y !== tile.modelData.y)
                    {
                        const m = Object.assign({}, settingsDisplayLayout.moved);
                        m[tile.modelData.name] = p;
                        settingsDisplayLayout.moved = m;
                        ServiceDisplay.change(tile.modelData.name, "position", p);
                    }
                }
            }

            Item
            {
                id: dragProxy
                parent: settingsDisplayLayout
                onXChanged: if (area.drag.active) tile.dragX = x
                onYChanged: if (area.drag.active) tile.dragY = y
            }
        }
    }

    ShellText
    {
        visible: settingsDisplayLayout.screens.length === 0
        anchors.centerIn: parent
        label: Tr.tr("common.noMonitorsFound")
        color: Theme.text3
    }
}
