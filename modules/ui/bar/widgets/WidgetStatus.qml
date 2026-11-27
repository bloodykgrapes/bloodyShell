import QtQuick

import "../../../core"
import "../../../services"
import "../components"

Widget
{
    id: widgetStatus

    readonly property bool connections: variant === "" || variant === "connections"
    readonly property bool system: variant === "" || variant === "system" || variant === "volume"
    readonly property bool keyboard: variant === "" || variant === "connections" || variant === "keyboard"
    readonly property bool network: variant === "" || variant === "connections" || variant === "network"
    readonly property bool bluetooth: variant === "" || variant === "connections" || variant === "bluetooth"
    readonly property bool separateButtons: variant !== ""

    component StatusButton: WidgetButton
    {
        id: statusButton

        required property url menu

        bubble: widgetStatus.separateButtons
        active: MenuState.menuWidget === statusButton
        function toggleMenu() { MenuState.toggle(menu, statusButton) }
    }

    Grid
    {
        columns: widgetStatus.vertical ? 1 : 6
        spacing: widgetStatus.separateButtons ? 6 : !Config.barAttach ? 8 : 0
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        WidgetButton
        {
            objectName: "virtualKeyboardBarButton"
            Accessible.role: Accessible.Button
            Accessible.name: Tr.tr("keyboard.title")
            visible: widgetStatus.connections && Config.virtualKeyboardEnabled
            bubble: widgetStatus.separateButtons
            active: ServiceVirtualKeyboard.visible
            icon: Icon.keyboard
            onClicked: ServiceVirtualKeyboard.toggle()
        }

        StatusButton
        {
            id: layout

            visible: widgetStatus.keyboard && Config.barWidgetKeyboardLayout && ServiceCompositor.keyboardLayout !== ""
            menu: Qt.resolvedUrl("../menus/MenuLayout.qml")
            text: ServiceCompositor.keyboardLayout

            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? ServiceCompositor.nextKeyboardLayout() : layout.toggleMenu()
        }

        StatusButton
        {
            id: network
            visible: widgetStatus.network

            menu: Qt.resolvedUrl("../menus/MenuNetwork.qml")
            icon: Icon.network
            onClicked: network.toggleMenu()
        }

        StatusButton
        {
            id: bluetooth
            visible: widgetStatus.bluetooth

            menu: Qt.resolvedUrl("../menus/MenuBluetooth.qml")
            icon: Icon.bluetooth
            onClicked: bluetooth.toggleMenu()
        }

        StatusButton
        {
            id: volume
            visible: widgetStatus.system

            readonly property bool showValue: Config.barWidgetVolumeValue && !widgetStatus.vertical && !widgetStatus.separateButtons

            menu: Qt.resolvedUrl("../menus/MenuVolume.qml")
            icon: Icon.volume
            text: showValue ? Math.round(ServiceAudio.volume * 100) : ""
            textReserve: showValue ? "00" : ""

            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => mouse.button === Qt.MiddleButton ? ServiceAudio.toggleMute() : volume.toggleMenu()
        }

        StatusButton
        {
            id: battery

            readonly property bool showValue: Config.barWidgetBatteryValue && !widgetStatus.vertical && !widgetStatus.separateButtons

            visible: widgetStatus.system && ServicePower.present
            menu: Qt.resolvedUrl("../menus/MenuBattery.qml")
            icon: Icon.battery
            text: showValue ? ServicePower.percent : ""
            textReserve: showValue ? "00" : ""
            color: ServicePower.low ? Theme.colorCritical : Theme.text2
            onClicked: battery.toggleMenu()
        }
    }
}
