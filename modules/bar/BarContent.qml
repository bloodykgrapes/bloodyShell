pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../core"
import "../services"

Item
{
    id: barContent

    readonly property bool glassContent: Theme.blur

    required property var host

    readonly property alias strip:   strip
    readonly property alias island0: island0
    readonly property alias island1: island1
    readonly property alias island2: island2
    readonly property alias panel0:  zone1.panel
    readonly property alias panel1:  zone2.panel
    readonly property alias panel2:  zone3.panel
    readonly property alias glass:   glassRegion

    readonly property real total:     host.isHorizontal ? width : height
    readonly property real thickness: host.thickness

    readonly property real band: host.floating ? Theme.barMargin + thickness
                               : host.frame ? host.frameThickness + (thickness - host.frameThickness) * host.reveal
                               : thickness

    readonly property real floatingLength: Math.min(
        Math.max(0, total - Theme.barMargin * 2),
        zone2.rowAlong + 2 * (Math.max(zone1.rowAlong, zone3.rowAlong) + Theme.barFloatingGap + Theme.barPadding))
    readonly property real floatingInset: Math.max(Theme.barMargin, (total - floatingLength) / 2)

    readonly property rect stripRect:
    {
        if (!host.floating) return Qt.rect(0, 0, 0, 0);
        const a0 = floatingInset, a1 = total - floatingInset, d0 = Theme.barMargin, d1 = Theme.barMargin + thickness;
        switch (Config.barSide)
        {
            case 0:  return Qt.rect(a0, d0, a1 - a0, d1 - d0);
            case 1:  return Qt.rect(a0, height - d1, a1 - a0, d1 - d0);
            case 2:  return Qt.rect(d0, a0, d1 - d0, a1 - a0);
            default: return Qt.rect(width - d1, a0, d1 - d0, a1 - a0);
        }
    }

    ShaderEffect
    {
        id: surface

        anchors.fill: parent

        function inset(edge) { return barContent.host.docked && edge === Config.barSide ? barContent.band : barContent.host.frame ? barContent.host.frameThickness : -60 }

        property size     size:        Qt.size(width, height)
        property vector4d inner:       Qt.vector4d(inset(2), inset(0), inset(3), inset(1))
        property real     innerRadius: barContent.host.frameRadius

        property rect island0:      barContent.host.floating ? barContent.stripRect : zone1.islandRect
        property rect island1:      zone2.islandRect
        property rect island2:      zone3.islandRect
        property real islandRadius: Math.min(Theme.barRadius, barContent.thickness / 2)

        property rect panel0:      zone1.blob
        property rect panel1:      zone2.blob
        property rect panel2:      zone3.blob
        property real panelRadius: Theme.barRadius
        property real smoothing:   Theme.barRadius

        property real panelSmoothing:
        {
            let k = Theme.barRadius;
            for (const z of [zone1, zone2, zone3]) if (z.floating && z.blob.width > 0) k = Math.min(k, z.floatSmoothing);
            return k;
        }

        property real  borderWidth: Theme.borderWidth
        property color fillColor:   Theme.barSurface
        property color borderColor: Theme.barSurfaceEdge

        property rect cut:
        {
            const c = barContent.host.frame && barContent.host.screen ? SurfaceState.dockCut[barContent.host.screen.name] : null;
            return c ? Qt.rect(c.x, c.y, c.w, c.h) : Qt.rect(0, 0, 0, 0);
        }

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/bar.frag.qsb")
    }

    Region
    {
        id: glassRegion

        Region
        {
            item: glassScreen
            Region { item: glassWindow; radius: barContent.host.frameRadius; intersection: Intersection.Subtract }
            Region { item: glassCut; intersection: Intersection.Subtract }
        }
        Region { item: island0; radius: surface.islandRadius }
        Region { item: island1; radius: surface.islandRadius }
        Region { item: island2; radius: surface.islandRadius }
        Region { item: glassPanel0; radius: surface.panelRadius }
        Region { item: glassPanel1; radius: surface.panelRadius }
        Region { item: glassPanel2; radius: surface.panelRadius }
    }

    component RectItem: Item
    {
        required property rect area
        x: area.x; y: area.y; width: area.width; height: area.height
    }

    Item { id: glassScreen; width: barContent.width; height: barContent.height }
    RectItem { id: glassWindow; area: Qt.rect(surface.inner.x, surface.inner.y, barContent.width - surface.inner.x - surface.inner.z, barContent.height - surface.inner.y - surface.inner.w) }
    RectItem { id: glassCut;    area: surface.cut }
    RectItem { id: glassPanel0; area: surface.panel0 }
    RectItem { id: glassPanel1; area: surface.panel1 }
    RectItem { id: glassPanel2; area: surface.panel2 }

    component WheelVolume: MouseArea
    {
        required property rect area
        x: area.x; y: area.y; width: area.width; height: area.height

        property real wheelRest: 0
        onWheel: wheel =>
        {
            wheelRest += wheel.angleDelta.y;
            const steps = wheelRest > 0 ? Math.floor(wheelRest / 120) : Math.ceil(wheelRest / 120);
            wheelRest -= steps * 120;
            if (steps !== 0) ServiceAudio.changeVolume(steps * 0.05);
        }
    }

    WheelVolume
    {
        id: strip
        area: !barContent.host.docked ? Qt.rect(0, 0, 0, 0)
            : Qt.rect(Config.barSide === Enums.EdgeRight ? barContent.width - barContent.band : 0,
                      Config.barSide === Enums.EdgeBottom ? barContent.height - barContent.band : 0,
                      barContent.host.isHorizontal ? barContent.width : barContent.band,
                      barContent.host.isHorizontal ? barContent.band : barContent.height)
    }
    WheelVolume { id: island0; area: surface.island0 }
    WheelVolume { id: island1; area: surface.island1 }
    WheelVolume { id: island2; area: surface.island2 }

    function withUpdate(list)
    {
        const all = [].concat(Config.barLayout.bar1 || [], Config.barLayout.bar2 || [], list);
        return all.indexOf("update") >= 0 ? list : list.concat(["update"]);
    }

    component Zone: BarZone
    {
        readonly property real edge: barContent.host.floating ? Theme.barMargin
                                   : barContent.host.frame ? barContent.host.frameThickness
                                   : barContent.host.docked ? 0 : Theme.barMargin

        anchors.fill: parent

        docked:      !barContent.host.islands
        thickness:   barContent.thickness
        band:        barContent.band
        stripDepth:  barContent.host.floating ? Theme.barMargin : 0
        stripInset:  barContent.host.floating ? barContent.floatingInset : stripDepth
        islandDepth: Theme.barMargin
        cornerInset: Theme.barMargin
        revealed:    barContent.host.revealed

        edgeMin:       edge + (barContent.host.frame ? barContent.host.frameRadius : 0)
        edgeMax:       barContent.total - edgeMin
        snapMin:       edge
        snapMax:       barContent.total - snapMin
        extendSnapped: barContent.host.docked
    }

    Zone { id: zone1; align: "start";  widgets: Config.barLayout.bar1 || [] }
    Zone { id: zone2; align: "center"; widgets: Config.barLayout.bar2 || [] }
    Zone { id: zone3; align: "end";    widgets: barContent.withUpdate(Config.barLayout.bar3 || []) }
}
