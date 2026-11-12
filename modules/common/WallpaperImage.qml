pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

import "../core"
import "../services"

Image
{
    id: image

    property string wallpaper: ""
    property string poster: ""
    property bool ready: false
    readonly property bool video: ServiceAppearance.isVideo(wallpaper)

    source: activity.active ? ServiceAppearance.fileUrl(video ? poster : wallpaper) : ""
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    sourceSize: Qt.size(720, 720)

    RenderActivity
    {
        id: activity
        target: image.parent || image
        onActiveChanged:
        {
            if (!image.ready) return;
            if (active) request.restart();
            else if (thumbnail.running) thumbnail.running = false;
        }
    }
    onWallpaperChanged:
    {
        poster = "";
        if (!ready) return;
        if (thumbnail.running) thumbnail.running = false;
        request.restart();
    }
    Component.onCompleted: { ready = true; request.restart(); }
    Timer
    {
        id: request
        interval: 0
        onTriggered:
        {
            if (!activity.active || !image.video || image.wallpaper === "") return;
            if (thumbnail.busy) { thumbnail.again = true; return; }
            thumbnail.path = image.wallpaper;
            thumbnail.again = false;
            thumbnail.run(Paths.commandFor("wallpaper", ["preview", image.wallpaper]));
        }
    }
    CommandProcess
    {
        id: thumbnail
        property string path: ""
        property bool again: false
        stdout: StdioCollector { id: result }
        onCompleted: code =>
        {
            if (code === 0 && path === image.wallpaper)
            {
                try { image.poster = JSON.parse(result.text).preview; }
                catch (error) { image.poster = ""; }
            }
            if (activity.active && (again || path !== image.wallpaper)) request.restart();
        }
    }
}
