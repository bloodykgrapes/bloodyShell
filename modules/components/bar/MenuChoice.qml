import QtQuick

import ".."
import "../../core"

Item
{
    id: menuChoice

    property var options: []
    property int current: 0

    signal selected(int index)

    width: parent ? parent.width : 200
    height: 30

    Rectangle { anchors.fill: parent; radius: Theme.radiusMedium; color: Theme.menuColorHover }

    Row
    {
        anchors { fill: parent; margins: 2 }
        spacing: 2

        Repeater
        {
            model: menuChoice.options

            Rectangle
            {
                required property int    index
                required property string modelData

                width: (menuChoice.width - 4 - (menuChoice.options.length - 1) * 2) / menuChoice.options.length
                height: parent.height
                radius: Theme.radiusSmall
                scale: segmentArea.pressed ? 0.97 : 1
                Behavior on scale
                {
                    enabled: Config.animationsEnabled
                    NumberAnimation { duration: 130; easing.type: Easing.OutBack }
                }
                color: menuChoice.current === index ? Theme.colorChosen
                    : segmentArea.containsMouse ? Theme.colorHover : "transparent"

                ShellText
                {
                    anchors.centerIn: parent

                    label: parent.modelData
                    color: menuChoice.current === parent.index ? Theme.text1 : Theme.text3
                }

                MouseArea
                {
                    id: segmentArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menuChoice.selected(parent.index)
                }
            }
        }
    }
}
