import QtQuick

import ".."
import "../../core"

Item
{
    id: menuLabel

    property string text: ""
    property bool   hint: false

    width: parent ? parent.width : 200
    height: hint ? 36 : 24

    ShellText
    {
        anchors
        {
            left: menuLabel.hint ? undefined : parent.left
            leftMargin: 10
            horizontalCenter: menuLabel.hint ? parent.horizontalCenter : undefined
            bottom: menuLabel.hint ? undefined : parent.bottom
            bottomMargin: 4
            verticalCenter: menuLabel.hint ? parent.verticalCenter : undefined
        }

        label: menuLabel.hint ? menuLabel.text : menuLabel.text.toUpperCase()
        size: menuLabel.hint ? 12 : 10
        color: Theme.text3
        font.letterSpacing: menuLabel.hint ? 0 : 0.8
    }
}
