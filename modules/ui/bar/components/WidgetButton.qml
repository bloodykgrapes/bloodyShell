pragma ComponentBehavior: Bound

import QtQuick

import "../../../animations"
import "../../../common"
import "../../../common" as Common
import "../../../core"

Common.InteractiveControl
{
    id: widgetButton

    readonly property bool containsMouse: enabled && hovered
    property alias pressed: pointer.pressed
    property alias acceptedButtons: pointer.acceptedButtons
    property alias cursorShape: pointer.cursorShape
    signal clicked(var mouse)
    signal pointerPressed(var mouse)
    signal wheel(var wheel)

    property bool active: false

    property string icon: ""
    property bool monochrome: false
    property string text: ""
    property string textReserve: ""
    property color  color: Theme.text2
    property real radius: Math.min(Theme.barWidgetRadius, height / 2)
    property color backgroundColor: pressed || active ? Theme.colorPressed
        : containsMouse ? Theme.colorHover : "transparent"

    property real iconSize: 16
    padding: 7
    spacing: 4

    readonly property bool hasIcon: icon !== ""
    readonly property bool hasText: text !== ""

    implicitHeight: Math.max(Theme.barWidgetHeight, Math.ceil(content.implicitHeight + padding))
    implicitWidth: hasText
        ? Math.ceil(content.implicitWidth + padding * 2)
        : Math.max(implicitHeight, Math.ceil(content.implicitWidth))

    cursorShape: Qt.PointingHandCursor

    readonly property bool lit: containsMouse || active

    scale: pressed ? 0.94 : containsMouse ? 1.1 : 1

    Spring on scale {}

    Rectangle
    {
        anchors.fill: parent
        radius: widgetButton.radius
        color: widgetButton.backgroundColor

        Tint on color {}
    }

    Row
    {
        id: content

        anchors.centerIn: parent
        spacing: widgetButton.hasIcon && widgetButton.hasText ? widgetButton.spacing : 0

        Image
        {
            visible: widgetButton.hasIcon
            anchors.verticalCenter: parent.verticalCenter

            layer.enabled: widgetButton.monochrome
            layer.effect: Monochrome
            {
                tint: widgetButton.lit ? Theme.text1 : widgetButton.color
                Tint on tint { }
            }

            source: widgetButton.icon
            opacity: widgetButton.lit ? 1 : 0.85

            Smooth on opacity {}

            width: widgetButton.hasIcon ? widgetButton.iconSize : 0
            height: widgetButton.iconSize
            sourceSize: Qt.size(Math.round(widgetButton.iconSize * 1.1), Math.round(widgetButton.iconSize * 1.1))
            mipmap: true

            smooth: true
            asynchronous: true
            fillMode: Image.PreserveAspectFit
        }

        Text
        {
            id: label

            visible: widgetButton.hasText
            anchors.verticalCenter: parent.verticalCenter

            text: widgetButton.text
            color: widgetButton.lit ? Theme.text1 : widgetButton.color

            Tint on color {}

            font.pixelSize: 12
            font.family: Theme.fontText

            width: Math.max(implicitWidth, reserve.advanceWidth)
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.92
        }
    }

    TextMetrics
    {
        id: reserve

        font: label.font
        text: widgetButton.textReserve
    }
    MouseArea
    {
        id: pointer
        objectName: "widgetPointer"
        anchors.fill: parent
        hoverEnabled: true
        onPressed: mouse => { widgetButton.focusFor(Qt.MouseFocusReason); widgetButton.pointerPressed(mouse); }
        onClicked: mouse => widgetButton.clicked(mouse)
        onWheel: wheel => { wheel.accepted = false; widgetButton.wheel(wheel); }
    }

}
