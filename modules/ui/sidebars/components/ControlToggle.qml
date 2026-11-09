import QtQuick

import "../../../animations"
import "../../../common"
import "../../../core"

Item
{
    id: control

    property string text: ""
    property string subtitle: ""
    property string icon: ""
    property bool checked: false
    property bool available: true
    readonly property color foreground: Theme.lightForeground(surface.color) ? "#ffffff" : "#000000"
    signal toggled(bool checked)

    implicitWidth: 160
    implicitHeight: 64
    enabled: available
    opacity: available ? 1 : 0.4
    activeFocusOnTab: true

    function toggle() { if (enabled) toggled(!checked) }
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) toggle(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) toggle(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) toggle(); event.accepted = true }

    Rectangle
    {
        id: surface
        anchors.fill: parent
        radius: Config.animationsFluid && area.containsMouse ? 16 : 18
        color: control.checked ? Theme.colorAccent : Qt.tint(Theme.frameColor, Theme.colorField)
        scale: area.pressed ? 0.96 : area.containsMouse && Config.animationsFluid ? 1.02 : 1
        Tint on color {}
        Glide on radius { duration: Theme.animationDurationControl }
        Spring on scale {}

        Rectangle
        {
            anchors.fill: parent
            radius: parent.radius
            color: area.pressed ? Theme.colorPressed : Theme.colorHoverStrong
            opacity: area.pressed || area.containsMouse || control.activeFocus ? 1 : 0
            Smooth on opacity {}
        }
        Rectangle
        {
            x: 12; y: (parent.height - height) / 2
            width: 38; height: 38; radius: 14
            color: control.checked ? Qt.rgba(control.foreground.r, control.foreground.g, control.foreground.b, 0.12) : "transparent"
            Tint on color {}
            ShellIcon
            {
                anchors.centerIn: parent
                icon: control.icon
                size: 21
                layer.enabled: true
                layer.effect: Monochrome { tint: control.foreground }
                scale: control.checked ? 1 : 0.9
                Spring on scale {}
            }
        }
        Column
        {
            x: 60
            width: Math.max(0, parent.width - x - 12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            ShellText { width: parent.width; label: control.text; size: 12; color: control.foreground; font.weight: Font.DemiBold }
            ShellText { width: parent.width; label: control.subtitle; size: 10; color: control.foreground; opacity: 0.7; textFormat: Text.PlainText }
        }
    }
    MouseArea
    {
        id: area
        objectName: "controlTogglePointer"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { control.forceActiveFocus(Qt.MouseFocusReason); control.toggle() }
    }

    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.description: subtitle
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onPressAction: toggle()
    Accessible.onToggleAction: toggle()
}
