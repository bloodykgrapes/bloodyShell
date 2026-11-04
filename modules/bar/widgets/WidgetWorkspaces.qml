pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../components"
import "../../components/bar"
import "../../core"
import "../../services"

Widget
{
    id: widgetWorkspaces

    padding: Theme.barWidgetPadding

    readonly property string outputName: QsWindow.window && QsWindow.window.screen ? QsWindow.window.screen.name : ""
    readonly property bool   hasOutputMatch:
    {
        const revision = ServiceCompositor.workspaceRevision;
        if (revision < 0 || outputName === "") return false;
        for (let i = 0; i < ServiceCompositor.workspacesList.count; i++)
            if (ServiceCompositor.workspacesList.get(i).output === outputName) return true;
        return false;
    }

    MouseArea
    {
        width: dots.width
        height: widgetWorkspaces.vertical ? dots.height : Theme.barWidgetHeight

        acceptedButtons: Qt.NoButton
        onWheel: wheel =>
        {
            const steps = widgetWorkspaces.wheelSteps(wheel);
            if (steps !== 0) ServiceCompositor.focusWorkspaceRelative(widgetWorkspaces.outputName, -steps);
        }

        Grid
        {
            id: dots

            anchors.verticalCenter: widgetWorkspaces.vertical ? undefined : parent.verticalCenter

            columns: widgetWorkspaces.vertical ? 1 : 1000
            spacing: 1

            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Repeater
            {
                model: ServiceCompositor.workspacesList

                MouseArea
                {
                    id: hit

                    required property var    wsId
                    required property int    wsIdx
                    required property string output
                    required property bool   focused
                    required property bool   activated
                    required property bool   urgent

                    readonly property bool current: output === ServiceCompositor.focusedOutput ? focused : activated

                    visible: !widgetWorkspaces.hasOutputMatch || output === widgetWorkspaces.outputName

                    Accessible.role: Accessible.Button
                    Accessible.name: Tr.tr("shell.workspaces") + " " + wsIdx
                    Accessible.checkable: true
                    Accessible.checked: current
                    Accessible.onPressAction: ServiceCompositor.focusWorkspace(output, wsIdx)

                    property real length: current ? 21 : 6
                    Glide on length {}

                    readonly property real span: length + 6

                    width:  widgetWorkspaces.vertical ? Theme.barWidgetHeight : span
                    height: widgetWorkspaces.vertical ? span : Theme.barWidgetHeight

                    hoverEnabled: true
                    cursorShape: current ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!current) ServiceCompositor.focusWorkspace(output, wsIdx)

                    Rectangle
                    {
                        id: dot

                        anchors.centerIn: parent
                        radius: Math.min(width, height) / 2

                        width:  widgetWorkspaces.vertical ? 6 : hit.length
                        height: widgetWorkspaces.vertical ? hit.length : 6

                        color: hit.urgent && !hit.current ? Theme.colorAttention
                            : hit.current ? Theme.colorAccent
                            : hit.containsMouse ? Theme.text2
                            : hit.activated ? Theme.text3 : Theme.text4

                        Tint on color { duration: 180 }
                    }
                }
            }
        }
    }
}
