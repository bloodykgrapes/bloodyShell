import QtQuick

import "../core"
import "../services"

Item
{
    id: notificationIcon

    property var n
    property int size: 40

    property string fixedSource: ""

    width: size
    height: size

    readonly property string source: fixedSource !== "" ? fixedSource : sourceOf(n)

    function sourceOf(n)
    {
        if (!n) return "";
        if (n.image !== "") return n.image;
        if (n.appIcon !== "")
        {
            if (n.appIcon.startsWith("/")) return "file://" + n.appIcon;
            return ServiceAppearance.iconPath(n.appIcon);
        }
        return "";
    }

    Rectangle
    {
        anchors.fill: parent
        radius: Math.round(notificationIcon.size / 4)
        color: Theme.menuColorHover
    }

    Image
    {
        id: image
        anchors.fill: parent
        anchors.margins: 4
        source: notificationIcon.source
        sourceSize.width: 96
        sourceSize.height: 96
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready
    }

    ShellIcon
    {
        anchors.centerIn: parent
        visible: image.status !== Image.Ready

        icon: Icon.bellON
    }
}
