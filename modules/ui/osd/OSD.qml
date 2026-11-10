pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../animations"
import "../../core"
import "../bar/components"

Item
{
    id: island

    required property var screen
    property real centerLimit: 300
    readonly property int side: Config.barSide
    readonly property bool menuHere: MenuState.menuActive && MenuState.menuOwner === zone
    readonly property bool keyboardWanted: menuHere && MenuState.menuKeyboard
    readonly property alias inputRegion: inputMask
    readonly property rect bodyRect: zone.islandRect
    readonly property rect panelRect: zone.blob

    Region
    {
        id: inputMask
        Region { item: body }
        Region { item: zone.panel }
    }
    Item
    {
        id: body
        x: zone.islandRect.x; y: zone.islandRect.y
        width: zone.islandRect.width; height: zone.islandRect.height
    }
    Rectangle
    {
        objectName: "islandNotificationSurface"
        anchors.fill: body
        radius: Theme.barRadius
        color: Theme.frameColor
        visible: zone.thickness > Theme.barThickness + 0.5
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
        thickness: contentThickness > 0 ? Math.max(Theme.barThickness, contentThickness + (isHorizontal ? 12 : 6)) : 0
        Glide on thickness { enabled: zone.animated }
        islandDepth: Theme.frameThickness
        cornerInset: Theme.frameThickness
        edgeMin: Theme.frameThickness + 12
        edgeMax: total - edgeMin
        snapMin: edgeMin
        snapMax: edgeMax
        revealed: true
    }
}
