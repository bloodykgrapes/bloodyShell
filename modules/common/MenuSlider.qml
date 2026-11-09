import QtQuick

import "../animations"
import "../core"

Item
{
    id: menuSlider

    property string icon: ""
    property string appIcon: ""
    property string label: ""
    property real   value: 0
    property bool   muted: false
    property bool   available: true

    signal moved(real value)
    signal iconClicked()

    readonly property real shown: drag.pressed ? drag.dragPos : value

    width: parent ? parent.width : 200
    height: label !== "" ? 44 : 36
    opacity: available ? 1 : 0.4
    enabled: available

    Rectangle
    {
        id: button

        x: 2
        anchors.verticalCenter: parent.verticalCenter
        width: 30; height: 30; radius: 15

        color: iconArea.pressed ? Theme.colorPressed : iconArea.containsMouse ? Theme.colorHover : "transparent"
        Tint on color {}

        ShellIcon
        {
            anchors.centerIn: parent
            visible: menuSlider.appIcon === ""
            icon: menuSlider.icon
            size: 16
            opacity: menuSlider.muted ? 0.55 : 1
        }
        Image
        {
            anchors.centerIn: parent
            visible: menuSlider.appIcon !== ""
            source: menuSlider.appIcon
            width: Math.round(20 * Config.themeScale)
            height: width
            sourceSize: Qt.size(48, 48)
            asynchronous: true
            opacity: menuSlider.muted ? 0.45 : 1
            Smooth on opacity {}
        }

        Rectangle
        {
            visible: menuSlider.appIcon !== "" && menuSlider.muted
            anchors.centerIn: parent
            width: 22; height: 2; radius: 1
            rotation: -45
            color: Theme.text1
        }

        MouseArea
        {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menuSlider.iconClicked()
        }
    }

    Item
    {
        id: track

        anchors
        {
            left: button.right; leftMargin: 8
            right: percent.left; rightMargin: 10
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: menuSlider.label !== "" ? 6 : 0
        }
        height: 20

        ShellText
        {
            anchors { left: parent.left; bottom: parent.top; bottomMargin: -4 }
            width: parent.width
            label: menuSlider.label
            size: 10
            color: Theme.text3
        }

        Rectangle
        {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: drag.containsMouse || drag.pressed ? 6 : 4
            radius: height / 2
            color: Theme.colorField

            Glide on height {}

            Rectangle
            {
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, menuSlider.shown)))
                height: parent.height
                radius: parent.radius
                color: menuSlider.muted ? Theme.text4 : Theme.colorAccent

                Tint on color {}
            }
        }

        MouseArea
        {
            id: drag

            property real dragPos: 0

            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function update(mx)
            {
                dragPos = Math.max(0, Math.min(1, (mx - 6) / track.width));
                menuSlider.moved(dragPos);
            }

            onPressed: mouse => update(mouse.x)
            onPositionChanged: mouse => { if (pressed) update(mouse.x) }

            onWheel: wheel =>
            {
                const step = wheel.angleDelta.y > 0 ? 0.05 : wheel.angleDelta.y < 0 ? -0.05 : 0;
                if (step !== 0) menuSlider.moved(Math.max(0, Math.min(1, Math.round((menuSlider.value + step) * 100) / 100)));
            }
        }
    }

    ShellText
    {
        id: percent

        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        width: reserve.advanceWidth
        horizontalAlignment: Text.AlignRight

        label: Math.round(menuSlider.shown * 100) + "%"
        color: Theme.text3
        size: 11

        TextMetrics { id: reserve; font: percent.font; text: "100%" }
    }
}
