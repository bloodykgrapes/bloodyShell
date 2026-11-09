import QtQuick

import "../core"

Behavior
{
    id: tint

    property int duration: 140

    enabled: Config.animationsEnabled

    ColorAnimation
    {
        duration: tint.duration
        easing.type: Easing.OutCubic
    }
}
