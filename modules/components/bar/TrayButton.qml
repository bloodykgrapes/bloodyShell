import QtQuick

import ".."
import "../../core"
import "../../services"

WidgetButton
{
    id: trayButton

    RenderActivity
    {
        id: activity
        target: trayButton
    }

    required property var trayItem

    signal launched()
    signal contextRequested()

    icon: ServiceApplications.trayIcon(trayItem ? trayItem.icon : "")
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    property real grow: Config.animationsFluid ? 0 : 1
    Component.onCompleted: grow = 1
    Spring on grow { enabled: Config.animationsFluid }
    opacity: Math.min(1, grow * 1.4)
    transform: Scale { origin.x: trayButton.width / 2; origin.y: trayButton.height / 2; xScale: 0.6 + 0.4 * trayButton.grow; yScale: xScale }

    onClicked: mouse =>
    {
        if (!trayItem) return;

        if (mouse.button === Qt.LeftButton)
        {
            const action = ServiceWindowActions.activateTrayItem(trayItem);

            if (action === "menu")
                trayButton.contextRequested();
            else if (action !== "none")
                trayButton.launched();
        }
        else if (mouse.button === Qt.RightButton)
        {
            if (trayItem.hasMenu)
                trayButton.contextRequested();
        }
        else
        {
            trayItem.secondaryActivate();
        }
    }

    Rectangle
    {
        id: attention

        readonly property bool on: trayButton.trayItem && trayButton.trayItem.status === 2

        visible: on
        x: parent.width - width - 3
        y: 3
        width: 6
        height: 6
        radius: 3
        color: Theme.colorAttention

        SequentialAnimation on scale
        {
            running: activity.active && attention.on && Config.animationsEnabled
            loops: Animation.Infinite
            onRunningChanged: if (!running) attention.scale = 1
            NumberAnimation { to: 1.5; duration: 520; easing.type: Easing.OutCubic }
            NumberAnimation { to: 1;   duration: 700; easing.type: Easing.InOutSine }
        }
    }
}
