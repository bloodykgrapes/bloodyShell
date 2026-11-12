import QtQuick

Rectangle
{
    id: key

    required property var host
    readonly property var colors: host.colors
    property string text: ""
    property string description: text
    property bool checked: false
    property bool accent: false
    property bool repeatable: false
    property bool animations: host.animations
    property bool fluid: host.fluid
    property string family: host.family
    property int textSize: host.width < 600 ? 14 : 17
    readonly property color onAccentColor: colors.onAccent
    signal activated(bool repeated)

    implicitHeight: 46
    height: host.keyHeight
    enabled: host.available
    radius: 10
    color: checked || accent ? colors.accent : colors.key
    scale: pointer.pressed ? 0.95 : 1
    opacity: enabled ? 1 : 0.4
    Behavior on color { enabled: key.animations; ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on opacity { enabled: key.animations; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on scale { enabled: key.animations; NumberAnimation { duration: key.fluid ? 220 : 120; easing.type: Easing.OutCubic } }

    Rectangle
    {
        objectName: "virtualKeyHover"
        anchors.fill: parent
        radius: key.radius
        color: key.checked || key.accent
            ? Qt.rgba(key.onAccentColor.r, key.onAccentColor.g, key.onAccentColor.b, pointer.pressed ? 0.14 : 0.08)
            : pointer.pressed ? key.colors.pressed : key.colors.hover
        opacity: key.enabled && (pointer.containsMouse || pointer.pressed) ? 1 : 0

        Behavior on color { enabled: key.animations; ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on opacity { enabled: key.animations; NumberAnimation { duration: 140; easing.type: Easing.InOutSine } }
    }

    Text
    {
        anchors { fill: parent; margins: 3 }
        text: key.text
        font.family: key.family
        font.pixelSize: key.textSize
        font.weight: key.checked || key.accent ? Font.DemiBold : Font.Medium
        color: key.checked || key.accent ? key.colors.onAccent : key.colors.text
        Behavior on color { enabled: key.animations; ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    MouseArea
    {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onDoubleClicked: { key.activated(false); if (key.repeatable) delay.restart(); }
        onPressed: if (key.repeatable) { key.activated(false); delay.restart(); }
        onClicked: if (!key.repeatable) key.activated(false)
        onReleased: { delay.stop(); repeat.stop(); }
        onCanceled: { delay.stop(); repeat.stop(); }
    }
    Timer { id: delay; interval: 420; onTriggered: if (pointer.pressed && key.enabled) { key.activated(true); repeat.start(); } }
    Timer { id: repeat; interval: 40; repeat: true; onTriggered: { if (pointer.pressed && key.enabled) key.activated(true); else stop(); } }
    onVisibleChanged: if (!visible) { delay.stop(); repeat.stop(); }
    onEnabledChanged: if (!enabled) { delay.stop(); repeat.stop(); }

    Accessible.role: Accessible.Button
    Accessible.name: description
    Accessible.checkable: checked
    Accessible.checked: checked
    Accessible.onPressAction: activated(false)
}
