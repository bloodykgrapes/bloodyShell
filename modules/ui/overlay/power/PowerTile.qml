import QtQuick

import "../../../animations"
import "../../../common"
import "../../../core"

Item
{
    id: powerTile

    property string icon: ""
    property string title: ""
    property bool   hold: false
    property bool   current: false
    property bool   danger: false
    signal hovered()
    signal triggered()

    readonly property bool pressed: area.pressed || fill.running
    readonly property color tone: danger ? Theme.colorCritical : Theme.colorAccent
    onEnabledChanged: if (!enabled) release()

    width: 112
    height: 136

    property real progress: 0
    readonly property int holdTime: 800
    function press()
    {
        if (!enabled) return;
        if (!hold) { triggered(); return; }
        drain.stop();
        fill.duration = holdTime * (1 - progress);
        fill.restart();
    }
    function release()
    {
        if (!hold || progress >= 1 || !fill || !drain) return;
        fill.stop();
        drain.restart();
    }
    NumberAnimation { id: fill; target: powerTile; property: "progress"; to: 1; easing.type: Easing.InOutQuad; onFinished: if (powerTile.progress >= 1) powerTile.triggered() }
    NumberAnimation { id: drain; target: powerTile; property: "progress"; to: 0; duration: 220; easing.type: Easing.OutCubic }

    Rectangle
    {
        anchors.fill: parent
        radius: 22
        color: Qt.rgba(Theme.text1.r, Theme.text1.g, Theme.text1.b, Theme.light ? 0.045 : 0.055)
        opacity: powerTile.current ? 0 : 1
        Smooth on opacity {}
    }

    Item
    {
        anchors.fill: parent
        scale: powerTile.pressed ? 0.96 : 1
        Spring on scale {}

        Rectangle
        {
            id: iconPlate
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            width: 48
            height: 48
            radius: 16
            color: Qt.rgba(powerTile.tone.r, powerTile.tone.g, powerTile.tone.b, powerTile.current ? 0.26 : powerTile.danger ? 0.12 : 0.10)
            scale: powerTile.current ? 1.08 : 1
            Spring on scale {}
            Tint on color {}

            ShellIcon
            {
                anchors.centerIn: parent
                icon: powerTile.icon
                size: 28
                zoom: 1.1
                opacity: powerTile.current ? 1 : 0.85
                Smooth on opacity {}
            }
        }
        Item
        {
            anchors.top: iconPlate.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(0, powerTile.width - 12)
            height: name.implicitHeight + hint.implicitHeight + 4

            ShellText
            {
                id: name
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                label: powerTile.title
                size: 13
                color: powerTile.danger ? Theme.colorCritical : powerTile.current ? Theme.text1 : Theme.text2
                font.weight: Font.Medium
                Tint on color {}
            }

            ShellText
            {
                id: hint
                anchors { top: name.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                label: Tr.tr("power.hold")
                size: 10
                color: powerTile.danger ? Theme.colorCritical : Theme.text3
                opacity: powerTile.hold ? (powerTile.current ? 1 : 0.7) : 0
                Smooth on opacity {}
            }
        }
    }

    MouseArea
    {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: powerTile.enabled
        onContainsMouseChanged: if (containsMouse) powerTile.hovered()
        onPressed: powerTile.press()
        onReleased: powerTile.release()
        onCanceled: powerTile.release()
        onExited: powerTile.release()
    }
}
