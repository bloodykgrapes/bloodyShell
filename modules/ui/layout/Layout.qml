pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

import "../../core"
import "../frame"

Scope
{
    id: layout

    required property var modelData
    readonly property alias canvasSurface: mainSurface
    readonly property var scene: mainSurface.scene
    readonly property var reservations: scene ? scene.reservations : [0, 0, 0, 0]

    component Surface: PanelWindow
    {
        id: windowSurface
        required property int edge
        readonly property bool isCanvas: edge < 0
        readonly property var scene: sceneLoader.item

        screen: layout.modelData
        color: "transparent"
        visible: Config.initialized && (isCanvas || layout.reservations[edge] > 0)
        anchors.top: isCanvas || edge === Enums.EdgeTop
        anchors.bottom: isCanvas || edge === Enums.EdgeBottom
        anchors.left: isCanvas || edge === Enums.EdgeLeft
        anchors.right: isCanvas || edge === Enums.EdgeRight
        margins { top: 0; bottom: 0; left: 0; right: 0 }
        implicitWidth: isCanvas ? 0 : 1
        implicitHeight: isCanvas ? 0 : 1
        exclusionMode: isCanvas ? ExclusionMode.Ignore : ExclusionMode.Normal
        mask: isCanvas && scene ? scene.inputRegion : emptyInput

        WlrLayershell.namespace: isCanvas ? "bloodyShell:layout" : "bloodyShell:reserve-" + edge
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: !isCanvas || !scene ? WlrKeyboardFocus.None
            : scene.sidebarHere ? WlrKeyboardFocus.Exclusive
            : scene.keyboardWanted ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Region { id: emptyInput }
        Binding
        {
            target: windowSurface
            property: "exclusiveZone"
            value: windowSurface.isCanvas ? 0 : layout.reservations[windowSurface.edge]
            when: !windowSurface.isCanvas
            restoreMode: Binding.RestoreNone
        }
        Loader
        {
            id: sceneLoader
            anchors.fill: parent
            active: windowSurface.isCanvas
            sourceComponent: Frame
            {
                screen: windowSurface.screen
                onRegionsChanged: if (windowSurface.mask) windowSurface.mask.changed()
            }
        }
    }

    Surface { id: mainSurface; edge: -1 }
    Variants
    {
        model: [Enums.EdgeTop, Enums.EdgeBottom, Enums.EdgeLeft, Enums.EdgeRight]
        Surface { required property int modelData; edge: modelData }
    }
}
