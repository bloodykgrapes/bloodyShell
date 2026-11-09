import QtQuick

import "../core"

Behavior
{
    id: appear

    property int delay: Config.animationsFluid ? 45 : 0
    property int duration: Config.animationsFluid ? 220 : 140
    property int fadeOut: 90

    enabled: Config.animationsEnabled

    SequentialAnimation
    {
        PauseAnimation { duration: appear.targetValue > 0.5 ? appear.delay : 0 }
        NumberAnimation
        {
            duration: appear.targetValue > 0.5 ? appear.duration : appear.fadeOut
            easing.type: Easing.OutCubic
        }
    }
}
