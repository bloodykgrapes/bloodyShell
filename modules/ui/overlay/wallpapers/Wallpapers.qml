import QtQuick

import "components" as Content
import ".."

OverlayView
{
    id: wallpapers

    name: "wallpapers"

    Content.WallpapersContent
    {
        anchors.fill: parent
        reveal: wallpapers.reveal
    }
}
