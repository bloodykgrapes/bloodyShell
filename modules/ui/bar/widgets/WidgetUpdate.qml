import QtQuick

import "../../../core"
import "../../../services"
import "../components"

Widget
{
    id: widgetUpdate

    active: ServiceUpdate.attention

    onActiveChanged: if (active && Config.animationsFluid) pulse.restart()
    Component.onCompleted: if (active && Config.animationsFluid) pulse.restart()

    WidgetButton
    {
        onClicked: ServiceUpdate.showPage()

        Rectangle
        {
            id: dot

            anchors.centerIn: parent
            width: 8
            height: width
            radius: width / 2
            color: Theme.colorAttention
        }

        Rectangle
        {
            anchors.centerIn: parent
            width: dot.width
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Theme.colorAttention
            border.width: 1.5

            property real wave: 0
            visible: Config.animationsFluid && wave > 0 && wave < 1
            scale: 1 + 1.6 * wave
            opacity: 0.7 * (1 - wave)

            NumberAnimation on wave
            {
                id: pulse
                running: false
                from: 0
                to: 1
                loops: 4
                duration: 1600
                easing.type: Easing.OutCubic
            }
        }
    }
}
