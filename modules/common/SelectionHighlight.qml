import QtQuick

import "../animations"
import "../core"

Rectangle
{
    id: selection

    property bool animate: true

    radius: 9
    color: Theme.accentShell ? Theme.accentAlpha(0.22) : Theme.inkAlpha(0.1)

    Glide on y { enabled: selection.animate && Config.animationsEnabled }
}
