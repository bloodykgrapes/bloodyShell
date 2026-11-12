import QtQuick

import "../core"

Text
{
    property string label: ""
    property int    size: 12

    visible: label !== ""

    color: Theme.text2

    text: label
    textFormat: Text.PlainText

    font.pixelSize: size
    font.family: Theme.fontText

    elide: Text.ElideRight
}
