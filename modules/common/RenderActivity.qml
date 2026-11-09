import QtQuick
import QtQuick.Window

QtObject
{
    required property Item target

    readonly property var window: target ? target.Window.window : null
    readonly property bool active:
    {
        if (!target || !target.visible || target.width <= 0 || target.height <= 0 || (window && !window.visible)) return false;
        for (let item = target; item; item = item.parent)
            if (item.opacity <= 0) return false;
        return true;
    }
}
