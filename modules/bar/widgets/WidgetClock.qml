import QtQuick
import Quickshell

import "../../components/bar"
import "../../core"

Widget
{
    id: widgetClock
    menu: Registry.widgets.clock.menu

    WidgetButton
    {
        readonly property string sep: widgetClock.vertical ? "\n" : ":"

        text: Qt.formatDateTime(clock.date,
            (Config.barWidgetClock24 ? "HH" : "hh") + sep + "mm" +
            (Config.barWidgetClockSeconds ? sep + "ss" : "") +
            (Config.barWidgetClock24 ? "" : (widgetClock.vertical ? "\nAP" : " AP")))
        textReserve: widgetClock.vertical ? "" : text.replace(/\d/g, "0")

        active: widgetClock.menuOpen
        onClicked: widgetClock.toggleMenu()
    }

    SystemClock
    {
        id: clock
        precision: Config.barWidgetClockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
