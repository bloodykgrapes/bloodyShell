import QtQuick

import "components" as Content
import ".."
import "../../../core"

OverlayView
{
    id: wallpapers

    name: "wallpapers"

    Content.WallpapersContent
    {
        anchors.fill: parent
        reveal: wallpapers.reveal
        opening: OverlayState.current === wallpapers.name
    }
}
