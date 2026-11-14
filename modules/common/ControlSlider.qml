pragma ComponentBehavior: Bound

import QtQuick
import "." as Common

import "../animations"
import "../core"

Common.InteractiveControl
{
    id: control


    property string text: ""
    property string icon: ""
    property string appIcon: ""
    property real value: 0
    property bool muted: false
    property bool available: true
    property bool iconAction: true
    property bool settled: false
    readonly property real shown: Math.max(0, Math.min(1, pointer.pressed ? pointer.dragValue : value))
    readonly property color fillColor: muted ? Theme.colorLine : Theme.colorAccent
    readonly property color fillText: Theme.lightForeground(fillPaint.color) ? "#ffffff" : "#000000"
    readonly property real iconWidth: 38
    property real fraction: shown

    signal moved(real value)
    signal iconClicked()

    TextMetrics
    {
        id: percentMetrics
        font.family: Theme.fontText
        font.pixelSize: 12
        font.weight: Font.DemiBold
        text: "100%"
    }

    implicitWidth: 320
    implicitHeight: 36
    enabled: available
    opacity: available ? 1 : 0.4
    activeFocusOnTab: true
    Component.onCompleted: Qt.callLater(() => settled = true)
    Glide on fraction { enabled: Config.animationsEnabled && control.settled && !pointer.pressed; duration: Theme.animationDurationControl }

    function adjust(delta) { if (enabled) moved(Math.max(0, Math.min(1, Math.round((shown + delta) * 100) / 100))) }
    function wheel(event)
    {
        const delta = event.angleDelta.y || event.angleDelta.x;
        if (delta) adjust(delta > 0 ? 0.05 : -0.05);
        event.accepted = delta !== 0;
    }
    Keys.onUpPressed: adjust(0.05)
    Keys.onRightPressed: adjust(0.05)
    Keys.onDownPressed: adjust(-0.05)
    Keys.onLeftPressed: adjust(-0.05)
    Keys.onPressed: event =>
    {
        if (event.key === Qt.Key_Home) moved(0);
        else if (event.key === Qt.Key_End) moved(1);
        else { event.accepted = false; return; }
        event.accepted = true;
    }
    Keys.onSpacePressed: event => { if (iconAction && !event.isAutoRepeat) iconClicked(); event.accepted = true }

    Rectangle
    {
        id: surface
        anchors.fill: parent
        radius: height / 2
        color: Theme.colorField
        scale: pointer.pressed ? 0.985 : control.hovered && Config.animationsFluid ? 1.012 : 1
        Spring on scale {}

        Readout { anchors.fill: parent; foreground: Theme.text1 }
        Item
        {
            id: fill
            objectName: "controlSliderFill"
            x: 0
            y: 0
            width: parent.width * control.fraction
            height: parent.height
            clip: true
            Rectangle
            {
                id: fillPaint
                width: surface.width
                height: surface.height
                radius: surface.radius
                color: control.fillColor
                Tint on color {}
            }
            Readout
            {
                x: -fill.x; y: -fill.y
                width: control.width; height: control.height
                foreground: control.fillText
            }
        }
        Rectangle
        {
            anchors.fill: parent
            radius: surface.radius
            color: Theme.inkAlpha(0.05)
            opacity: control.hovered || pointer.pressed || control.visualFocus ? 1 : 0
            Smooth on opacity {}
        }
    }

    MouseArea
    {
        id: pointer
        objectName: "controlSliderPointer"
        property real dragValue: 0
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.SizeHorCursor
        function update(x, y)
        {
            dragValue = Math.max(0, Math.min(1, x / width));
            control.moved(dragValue);
        }
        onPressed: mouse => { control.focusFor(Qt.MouseFocusReason); update(mouse.x, mouse.y) }
        onPositionChanged: mouse => { if (pressed) update(mouse.x, mouse.y) }
        onWheel: wheel => control.wheel(wheel)
    }
    MouseArea
    {
        objectName: "controlSliderIcon"
        x: 4
        y: 0
        width: control.iconWidth; height: parent.height
        enabled: control.iconAction
        cursorShape: Qt.PointingHandCursor
        onClicked: { control.focusFor(Qt.MouseFocusReason); control.iconClicked() }
        onWheel: wheel => control.wheel(wheel)
    }

    Accessible.role: Accessible.Slider
    Accessible.name: text
    Accessible.description: Math.round(shown * 100) + "%"
    Accessible.onIncreaseAction: adjust(0.05)
    Accessible.onDecreaseAction: adjust(-0.05)

    component Readout: Item
    {
        id: readout
        required property color foreground

        ShellIcon
        {
            x: 12
            y: (parent.height - height) / 2
            icon: control.icon
            visible: control.appIcon === ""
            size: 18
            layer.enabled: true
            layer.effect: Monochrome { tint: readout.foreground }
        }
        ShellIcon
        {
            x: 10
            y: (parent.height - height) / 2
            icon: control.appIcon
            size: 22
            opacity: control.muted ? 0.6 : 1
            Smooth on opacity {}

            Rectangle
            {
                anchors.centerIn: parent
                visible: control.muted
                width: parent.width
                height: 2
                radius: 1
                rotation: -45
                color: readout.foreground
            }
        }
        ShellText
        {
            x: control.iconWidth + 6
            y: (parent.height - height) / 2
            width: Math.max(0, parent.width - x - percentMetrics.advanceWidth - 28)
            visible: control.width >= 220
            label: control.text
            size: 12
            color: readout.foreground
            font.weight: Font.Medium
        }
        ShellText
        {
            x: parent.width - width - 14
            y: (parent.height - height) / 2
            label: control.available ? Math.round(control.shown * 100) + "%" : "—"
            size: 12
            color: readout.foreground
            font.weight: Font.DemiBold
        }
    }
}
