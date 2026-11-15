pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../animations"
import "../../core"
import "../../services"
import "../bar/components"

Item
{
    id: island

    required property var screen
    readonly property string islandOutput: screen ? screen.name : ""
    readonly property real islandMenuProgress: zone.progress
    property real centerLimit: 300
    readonly property int side: Config.barSide
    readonly property bool menuHere: MenuState.menuActive && MenuState.menuOwner === zone
    readonly property bool keyboardWanted: menuHere && MenuState.menuKeyboard
    readonly property bool recordingOnly: !menuHere && zone.singleWidget !== null && zone.singleWidget.recording
    readonly property bool expanded: menuHere || (zone.singleWidget !== null && zone.singleWidget.active && !recordingOnly)
    property real expansion: expanded ? 1 : 0
    Glide on expansion {}
    readonly property bool capturing: ServiceIsland.recordingActive && !ServiceLock.locked
    property real captureReveal: capturing ? 1 : 0
    Smooth on captureReveal { duration: 160 }
    readonly property real expansionProgress: Config.animationsEnabled ? Math.min(1, Math.max(0, expansion)) : expanded ? 1 : 0
    readonly property real captureProgress: Config.animationsEnabled ? captureReveal : capturing ? 1 : 0
    readonly property real islandReveal: recordingOnly || captureProgress > 0.001 ? expansionProgress : 1
    Component.onDestruction: if (menuHere) MenuState.close()
    readonly property alias inputRegion: inputMask
    readonly property rect bodyRect:
    {
        const full = zone.islandRect;
        if (menuHere) return full;
        if (expansionProgress < 0.001 || full.width <= 0 || full.height <= 0) return Qt.rect(0, 0, 0, 0);
        if (!recordingOnly && captureProgress <= 0.001) return full;
        const amount = expansionProgress;
        const width = Math.max(mark.width, full.width - (side < 2 ? Theme.barPadding * 2 : Theme.barThickness - mark.width) * (1 - amount));
        const height = Math.max(mark.height, full.height - (side < 2 ? Theme.barThickness - mark.height : Theme.barPadding * 2) * (1 - amount));
        const centerX = mark.x + mark.width / 2 + (full.x + full.width / 2 - mark.x - mark.width / 2) * amount;
        const centerY = mark.y + mark.height / 2 + (full.y + full.height / 2 - mark.y - mark.height / 2) * amount;
        return Qt.rect(centerX - width / 2, centerY - height / 2, width, height);
    }
    readonly property rect panelRect: zone.blob

    Region
    {
        id: inputMask
        Region { item: island.expanded ? body : null }
        Region { item: zone.panel }
    }
    Item
    {
        id: body
        x: island.bodyRect.x; y: island.bodyRect.y
        width: island.bodyRect.width; height: island.bodyRect.height
    }
    Rectangle
    {
        objectName: "islandNotificationSurface"
        anchors.fill: body
        radius: Theme.barRadius
        color: Theme.frameColor
        visible: island.expansionProgress > 0.001 && zone.thickness > Theme.barThickness + 0.5
    }
    BarZone
    {
        id: zone
        anchors.fill: parent
        side: island.side
        align: "center"
        widgets: ["island"]
        docked: false
        adaptive: true
        thickness: visibleMenu ? 0 : contentThickness > 0 ? Math.max(Theme.barThickness, contentThickness + (isHorizontal ? 12 : 6)) : 0
        Glide on thickness { enabled: zone.animated }
        islandDepth: Theme.frameThickness
        cornerInset: Theme.frameThickness
        edgeMin: Theme.frameThickness + 12
        edgeMax: total - edgeMin
        snapMin: edgeMin
        snapMax: edgeMax
        revealed: true
    }

    Rectangle
    {
        id: mark
        objectName: "recordingMark"
        readonly property real edgeCenter: Theme.frameThickness + Theme.barThickness / 2
        width: 10; height: 10; radius: 5
        x: island.side === Enums.EdgeLeft ? edgeCenter - width / 2
            : island.side === Enums.EdgeRight ? parent.width - edgeCenter - width / 2 : (parent.width - width) / 2
        y: island.side === Enums.EdgeTop ? edgeCenter - height / 2
            : island.side === Enums.EdgeBottom ? parent.height - edgeCenter - height / 2 : (parent.height - height) / 2
        color: Theme.colorCritical
        opacity: island.captureProgress * (1 - island.expansionProgress)
        visible: !ServiceLock.locked && opacity > 0.001
        Accessible.role: Accessible.StaticText
        Accessible.name: Tr.tr("recording.active") + " " + ServiceRecording.detail
    }
}
