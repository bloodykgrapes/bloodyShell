import QtQuick

import "../../components"
import "../../components/bar"
import "../../core"
import "../../services"

Widget
{
    id: widgetWindow

    property bool   stale: false
    property string title: Config.barWidgetWindowAppID ? ServiceCompositor.windowAppId : ServiceCompositor.windowTitle

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

        function onWindowTitleChanged()
        {
            const t = title;
            if (t === "") return;
            if (label.text === "" || !widgetWindow.active) label.text = t;
            else swap.restart();
        }
    }

    Text
    {
        id: label
        anchors.verticalCenter: parent.verticalCenter

        visible: text !== ""

        color: Theme.text2

        font.pixelSize: Math.round(12 * Config.themeScale)
        font.family: Theme.fontText

        property real fade: 1
        property real dim: ServiceCompositor.windowFocused ? 1 : 0.5
        Smooth on dim { duration: 200 }

        opacity: fade * dim
        elide: Text.ElideRight
        width: Math.min(implicitWidth, Theme.titleMaxWidth)

        Component.onCompleted: text = title
    }

    SequentialAnimation
    {
        id: swap

        NumberAnimation { target: label; property: "fade"; to: 0; duration: Config.animationsEnabled ? 90 : 0 }
        ScriptAction { script: if (title !== "") label.text = title }
        NumberAnimation { target: label; property: "fade"; to: 1; duration: Config.animationsEnabled ? 140 : 0 }
    }
}
