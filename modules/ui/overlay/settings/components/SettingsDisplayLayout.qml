import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../../../../src/DisplayLayout.js" as DisplayLayout

Item
{
    id: settingsDisplayLayout

    property string selected: ""
    signal picked(string name)

    implicitWidth: 520
    width: parent ? parent.width : implicitWidth
    height: 220
    clip: true

    readonly property var screens: ServiceDisplay.outputs.filter(output => output.logical).map(output =>
    {
        const mode = output.current_mode !== null ? output.modes[output.current_mode] : null;
        return {
            name: output.name,
            x: output.logical.x, y: output.logical.y,
            w: output.logical.width, h: output.logical.height,
            detail: mode ? mode.width + " × " + mode.height : ""
        };
    })

    readonly property real pad: 18
    readonly property var positions: screens.map(m => Object.assign({}, m, moved[m.name] || {}))
    readonly property var frame: dragging ? drag.frame : DisplayLayout.fit(positions, width, height, pad)
    readonly property bool dragging: drag !== null
    readonly property var preview: dragging ? drag.position : null
    readonly property string geometry: JSON.stringify(screens)
    property var drag: null
    property var moved: ({})

    onScreensChanged: moved = {}
    onGeometryChanged: cancelDrag()
    onWidthChanged: cancelDrag()
    onHeightChanged: cancelDrag()
    onVisibleChanged: if (!visible) cancelDrag()
    onEnabledChanged: if (!enabled) cancelDrag()

    function beginDrag(name)
    {
        drag = { name: name, frame: frame, position: null };
    }

    function updatePreview(name, x, y, w, h)
    {
        if (!dragging || drag.name !== name) return;
        const moving = { name: name, x: (x - frame.ox) / frame.s, y: (y - frame.oy) / frame.s, w: w, h: h };
        drag = Object.assign({}, drag, { position: DisplayLayout.snap(positions, moving, 8 / frame.s) });
    }

    function cancelDrag()
    {
        drag = null;
    }

    function finishDrag(name)
    {
        if (!dragging || drag.name !== name) return;
        const p = preview;
        const before = positions.find(m => m.name === name);
        const changed = p && before && (p.x !== before.x || p.y !== before.y);
        if (changed) moved = Object.assign({}, moved, { [name]: p });
        cancelDrag();
        if (changed) ServiceDisplay.change(name, "position", p);
    }

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Theme.colorField
    }

    Rectangle
    {
        readonly property var screen: settingsDisplayLayout.dragging ? settingsDisplayLayout.screens.find(m => m.name === settingsDisplayLayout.drag.name) : undefined
        visible: settingsDisplayLayout.preview !== null && screen !== undefined
        x: settingsDisplayLayout.frame.ox + (settingsDisplayLayout.preview ? settingsDisplayLayout.preview.x : 0) * settingsDisplayLayout.frame.s
        y: settingsDisplayLayout.frame.oy + (settingsDisplayLayout.preview ? settingsDisplayLayout.preview.y : 0) * settingsDisplayLayout.frame.s
        width: screen ? screen.w * settingsDisplayLayout.frame.s : 0
        height: screen ? screen.h * settingsDisplayLayout.frame.s : 0
        radius: Theme.radiusMedium
        color: Qt.rgba(Theme.colorAccent.r, Theme.colorAccent.g, Theme.colorAccent.b, 0.12)
        border.width: 2
        border.color: Theme.colorAccent
    }

    Repeater
    {
        model: settingsDisplayLayout.screens.length

        Rectangle
        {
            id: tile

            required property int index
            readonly property var modelData: settingsDisplayLayout.screens[index] || { name: "", x: 0, y: 0, w: 0, h: 0, detail: "" }
            readonly property bool current: modelData.name === settingsDisplayLayout.selected
            readonly property bool moving: settingsDisplayLayout.dragging && settingsDisplayLayout.drag.name === modelData.name
            objectName: "displayTile-" + modelData.name

            readonly property var at: settingsDisplayLayout.moved[modelData.name] || modelData
            x: moving ? dragProxy.x : settingsDisplayLayout.frame.ox + at.x * settingsDisplayLayout.frame.s
            y: moving ? dragProxy.y : settingsDisplayLayout.frame.oy + at.y * settingsDisplayLayout.frame.s
            width: Math.max(24, modelData.w * settingsDisplayLayout.frame.s)
            height: Math.max(16, modelData.h * settingsDisplayLayout.frame.s)
            z: moving ? 2 : current ? 1 : 0
            opacity: moving ? 0.65 : 1

            radius: Theme.radiusMedium
            color: current ? Theme.colorSelection : Theme.colorHover
            border.width: current ? 2 : 1
            border.color: current ? Theme.colorAccent : Theme.colorLine
            Tint on color {}
            Smooth on x { duration: 220; enabled: Config.animationsEnabled && !settingsDisplayLayout.dragging }
            Smooth on y { duration: 220; enabled: Config.animationsEnabled && !settingsDisplayLayout.dragging }

            Column
            {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - 12)
                spacing: 2
                ShellText
                {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    label: tile.modelData.name
                    size: 12
                    color: Theme.text1
                    font.weight: Font.DemiBold
                }
                ShellText
                {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    label: tile.modelData.detail
                    size: 10
                    color: Theme.text3
                }
            }

            MouseArea
            {
                id: area
                objectName: "displayDrag-" + tile.modelData.name
                anchors.fill: parent
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                preventStealing: true

                drag.target: settingsDisplayLayout.screens.length > 1 ? dragProxy : null
                drag.threshold: 4

                onPressed:
                {
                    settingsDisplayLayout.picked(tile.modelData.name);
                    dragProxy.x = tile.x;
                    dragProxy.y = tile.y;
                }
                drag.onActiveChanged:
                {
                    if (drag.active)
                    {
                        settingsDisplayLayout.beginDrag(tile.modelData.name);
                        dragProxy.updatePreview();
                    }
                }
                onReleased: settingsDisplayLayout.finishDrag(tile.modelData.name)
                onCanceled: settingsDisplayLayout.cancelDrag()
            }

            Item
            {
                id: dragProxy
                parent: settingsDisplayLayout
                function updatePreview() { settingsDisplayLayout.updatePreview(tile.modelData.name, x, y, tile.modelData.w, tile.modelData.h); }
                onXChanged: updatePreview()
                onYChanged: updatePreview()
            }
        }
    }

    ShellText
    {
        visible: settingsDisplayLayout.screens.length === 0
        anchors.centerIn: parent
        label: Tr.tr("common.noDisplays")
        color: Theme.text3
    }
}
