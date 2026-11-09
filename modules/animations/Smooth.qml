import QtQuick

import "../core"

Behavior
{
    id: smooth

    property int duration: 140

    enabled: Config.animationsEnabled

    NumberAnimation
    {
        duration: smooth.duration
        easing.type: Easing.OutCubic
    }
}
