import QtQuick

import "../../components/bar"
import "../../core"
import "../../services"

Widget
{
    id: widgetStatus

    component StatusButton: WidgetButton
    {
        id: statusButton

        required property url menu

        active: MenuState.menuWidget === statusButton
        function toggleMenu() { MenuState.toggle(menu, statusButton) }
    }

    Grid
    {
        columns: widgetStatus.vertical ? 1 : 5
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        StatusButton
        {
            id: layout

            visible: ServiceCompositor.keyboardLayout !== ""
            menu: Qt.resolvedUrl("../menus/MenuLayout.qml")
            text: ServiceCompositor.keyboardLayout

            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? ServiceCompositor.nextKeyboardLayout() : layout.toggleMenu()
        }

        StatusButton
        {
            id: network

            menu: Qt.resolvedUrl("../menus/MenuNetwork.qml")
            icon: Icon.network
            onClicked: network.toggleMenu()
        }

        StatusButton
        {
            id: bluetooth

            menu: Qt.resolvedUrl("../menus/MenuBluetooth.qml")
            icon: Icon.bluetooth
            onClicked: bluetooth.toggleMenu()
        }

        StatusButton
        {
            id: volume

            menu: Qt.resolvedUrl("../menus/MenuVolume.qml")
            icon: Icon.volume

            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => mouse.button === Qt.MiddleButton ? ServiceAudio.toggleMute() : volume.toggleMenu()
            onWheel: wheel =>
            {
                const steps = widgetStatus.wheelSteps(wheel);
                if (steps !== 0) ServiceAudio.changeVolume(steps * 0.05);
            }
        }

        StatusButton
        {
            id: battery

            readonly property bool showValue: Config.barWidgetBatteryValue && !widgetStatus.vertical

            visible: ServicePower.present
            menu: Qt.resolvedUrl("../menus/MenuBattery.qml")
            icon: Icon.battery
            text: showValue ? ServicePower.percent : ""
            textReserve: showValue ? "100" : ""
            color: ServicePower.low ? Theme.colorCritical : Theme.text2
            onClicked: battery.toggleMenu()
        }
    }
}
