import QtQuick

import "plugin"

Item
{
    id: monitor

    property var targetWindow: null
    property bool listening: false

    signal released()

    KeyboardMonitor
    {
        targetWindow: monitor.targetWindow
        listening: monitor.listening
        onReleased: monitor.released()
    }
}
