pragma ComponentBehavior: Bound

import QtQuick

import "../../../core"

Item
{
    id: selection

    property int mode: Enums.ScreenshotArea
    property rect region: Qt.rect(0, 0, 0, 0)
    readonly property bool valid: region.width >= 1 && region.height >= 1
    property point start: Qt.point(0, 0)
    property rect before: Qt.rect(0, 0, 0, 0)
    property string operation: ""

    function bounds(left, top, right, bottom)
    {
        const x = Math.max(0, Math.min(width, Math.min(left, right)));
        const y = Math.max(0, Math.min(height, Math.min(top, bottom)));
        region = Qt.rect(x, y, Math.max(0, Math.min(width, Math.max(left, right)) - x), Math.max(0, Math.min(height, Math.max(top, bottom)) - y));
    }
    function reset()
    {
        region = Qt.rect(0, 0, 0, 0);
        if (mode === Enums.ScreenshotScreen) region = Qt.rect(0, 0, width, height);
    }
    function hit(x, y)
    {
        if (!valid || x < region.x - 8 || x > region.x + region.width + 8 || y < region.y - 8 || y > region.y + region.height + 8) return "new";
        const vertical = Math.abs(y - region.y) < 8 ? "n" : Math.abs(y - region.y - region.height) < 8 ? "s" : "";
        const horizontal = Math.abs(x - region.x) < 8 ? "w" : Math.abs(x - region.x - region.width) < 8 ? "e" : "";
        return vertical + horizontal || "move";
    }
    function update(x, y)
    {
        const dx = x - start.x, dy = y - start.y;
        if (operation === "new") bounds(start.x, start.y, x, y);
        else if (operation === "move")
            region = Qt.rect(Math.max(0, Math.min(width - before.width, before.x + dx)), Math.max(0, Math.min(height - before.height, before.y + dy)), before.width, before.height);
        else bounds(before.x + (operation.includes("w") ? dx : 0), before.y + (operation.includes("n") ? dy : 0),
            before.x + before.width + (operation.includes("e") ? dx : 0), before.y + before.height + (operation.includes("s") ? dy : 0));
    }

    onModeChanged: reset()
    onWidthChanged: if (mode === Enums.ScreenshotScreen) reset()
    onHeightChanged: if (mode === Enums.ScreenshotScreen) reset()
    Component.onCompleted: reset()

    MouseArea
    {
        id: pointer
        objectName: "screenshotPointer"
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape:
        {
            if (selection.mode === Enums.ScreenshotScreen) return Qt.ArrowCursor;
            const hit = selection.hit(mouseX, mouseY);
            return hit === "nw" || hit === "se" ? Qt.SizeFDiagCursor : hit === "ne" || hit === "sw" ? Qt.SizeBDiagCursor
                : hit === "n" || hit === "s" ? Qt.SizeVerCursor : hit === "e" || hit === "w" ? Qt.SizeHorCursor
                : hit === "move" ? Qt.SizeAllCursor : Qt.CrossCursor;
        }
        onPressed: mouse =>
        {
            if (selection.mode !== Enums.ScreenshotArea) return;
            selection.start = Qt.point(mouse.x, mouse.y);
            selection.before = selection.region;
            selection.operation = selection.hit(mouse.x, mouse.y);
            if (selection.operation === "new") selection.region = Qt.rect(mouse.x, mouse.y, 0, 0);
        }
        onPositionChanged: mouse =>
        {
            if (selection.mode === Enums.ScreenshotArea && pressed) selection.update(mouse.x, mouse.y);
        }
        onReleased: mouse => { if (selection.mode === Enums.ScreenshotArea) selection.update(mouse.x, mouse.y); }
    }

    Rectangle { x: 0; y: 0; width: selection.width; height: selection.region.y; color: "#85000000" }
    Rectangle { x: 0; y: selection.region.y + selection.region.height; width: selection.width; height: Math.max(0, selection.height - y); color: "#85000000" }
    Rectangle { x: 0; y: selection.region.y; width: selection.region.x; height: selection.region.height; color: "#85000000" }
    Rectangle { x: selection.region.x + selection.region.width; y: selection.region.y; width: Math.max(0, selection.width - x); height: selection.region.height; color: "#85000000" }

    Rectangle
    {
        x: selection.region.x; y: selection.region.y
        width: selection.region.width; height: selection.region.height
        visible: selection.valid
        color: "transparent"
        border.width: 1
        border.color: "#000000"
        Rectangle { anchors { fill: parent; margins: 1 } color: "transparent"; border.width: 1; border.color: "#ffffff" }

        Repeater
        {
            model: selection.mode === Enums.ScreenshotArea ? [[0,0], [0.5,0], [1,0], [1,0.5], [1,1], [0.5,1], [0,1], [0,0.5]] : []
            Rectangle
            {
                required property var modelData
                x: parent.width * modelData[0] - width / 2
                y: parent.height * modelData[1] - height / 2
                width: 7; height: 7; radius: 2
                color: "#ffffff"
                border.width: 1
                border.color: "#000000"
            }
        }
    }
}
