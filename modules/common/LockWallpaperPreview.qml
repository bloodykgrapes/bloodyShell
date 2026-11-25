import QtQuick

Image
{
    // All outputs share this first-frame image until their detailed wallpaper is ready.
    // The lock view crops the fitted decode during layout.
    sourceSize: Qt.size(768, 768)
    asynchronous: true
    cache: true
}
