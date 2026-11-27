import QtQuick

import "../core"

QtObject
{
    id: reveal

    required property bool opened
    property bool animated: Config.animationsEnabled
    property real progress: opened ? 1 : 0
    readonly property real contentOpacity:
    {
        const fade = Math.max(0, Math.min(1, (progress - 0.12) / 0.56));
        return fade * fade * (3 - 2 * fade);
    }

    Ease on progress
    {
        enabled: reveal.animated
        durationByDistance: true
        duration: Theme.animationDuration(reveal.opened ? (Config.animationsFluid ? 310 : 230) : (Config.animationsFluid ? 210 : 170))
        curve: reveal.opened ? [0.22, 0.38, 0.26, 1.0, 1.0, 1.0] : [0.26, 0.0, 0.58, 1.0, 1.0, 1.0]
    }
}
