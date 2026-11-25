import QtQuick

import "../core"

Image
{
    objectName: "shellWallpaperTexture"
    source: ShellMaterial.wallpaper
    // A small, cached wallpaper sample produces the color wash without a per-panel blur pass.
    sourceSize: Qt.size(16, 16)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
}
