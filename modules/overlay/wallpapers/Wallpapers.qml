import QtQuick

import ".."
import "../../core"

Overlay
{
    id: wallpapers

    active: OverlayState.wallpapersActive
    onHide: OverlayState.hide("wallpapers")

    WallpapersContent
    {
        anchors.fill: parent
        reveal: wallpapers.reveal
    }
}
