import QtQuick

import "../core"

Text
{
    id: shellText

    style: Theme.onGlass(shellText) ? Text.Outline : Text.Normal
    styleColor: Theme.foregroundShadow

    property string label: ""
    property int    size: 12

    visible: label !== ""

    color: Theme.text2

    text: label

    font.pixelSize: Math.round(size * Config.themeScale)
    font.family: Theme.fontText

    elide: Text.ElideRight
}
