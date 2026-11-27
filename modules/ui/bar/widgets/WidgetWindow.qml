import QtQuick
import Quickshell

import "../../../animations"
import "../../../core"
import "../../../services"
import "../components"

Widget
{
    id: widgetWindow

    property bool   stale: false
    property string title: Config.barWidgetWindowMode === 2 ? ServiceCompositor.windowAppId
        : Config.barWidgetWindowMode === 1 ? ServiceApplications.appName(ServiceCompositor.windowAppId, ServiceCompositor.windowAppId)
        : ServiceCompositor.windowTitle

    active: title !== "" && !stale

    Timer { id: grace; interval: 1500; onTriggered: widgetWindow.stale = true }

    Connections
    {
        target: ServiceCompositor

        function onWindowFocusedChanged()
        {
            if (ServiceCompositor.windowFocused) { grace.stop(); widgetWindow.stale = false }
            else grace.restart();
        }

    }
    onTitleChanged:
    {
        if (title === "") return;
        if (label.text === "" || !active) label.text = title;
        else swap.restart();
    }

    Item
    {
        readonly property bool hasBackground: !Config.barAttach
        readonly property real length: label.width + (hasBackground ? 20 : 0)
        readonly property real thickness: hasBackground ? Theme.barStandaloneWidgetHeight : Theme.barWidgetHeight
        implicitWidth: widgetWindow.vertical ? thickness : length
        implicitHeight: widgetWindow.vertical ? length : thickness

        Rectangle
        {
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: parent.hasBackground ? Theme.panelButtonBackground : "transparent"
            Tint on color {}
        }

        Text
        {
            id: label
            anchors.centerIn: parent
            rotation: widgetWindow.vertical ? -90 : 0

            visible: text !== ""

            color: Theme.text2

            font.pixelSize: 12
            font.family: Theme.fontText

            property real fade: 1
            property real dim: ServiceCompositor.windowFocused ? 1 : 0.5
            Smooth on dim { duration: 200 }

            opacity: fade * dim
            elide: Text.ElideRight
            width: Math.min(implicitWidth, QsWindow.window && QsWindow.window.width < 1100 ? 90 : Theme.titleMaxWidth)

            Component.onCompleted: text = widgetWindow.title
        }
    }

    SequentialAnimation
    {
        id: swap

        NumberAnimation { target: label; property: "fade"; to: 0; duration: Config.animationsEnabled ? 90 : 0 }
        ScriptAction { script: if (title !== "") label.text = title }
        NumberAnimation { target: label; property: "fade"; to: 1; duration: Config.animationsEnabled ? 140 : 0 }
    }
}
