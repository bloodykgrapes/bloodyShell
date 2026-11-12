pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia

import "../../animations"
import "../../common"
import "../../core"
import "../../services"

Item
{
    id: wallpaper
    readonly property string path: ServiceAppearance.videoPath
    readonly property bool paused: ServiceLock.locked || !activity.active
    property bool revealed: false
    clip: true

    opacity: revealed && player.hasVideo && player.error === MediaPlayer.NoError ? 1 : 0
    Smooth on opacity { duration: Config.wallpaperTransition === "none" ? 0 : 350 }
    RenderActivity { id: activity; target: wallpaper.parent || wallpaper }

    function playback()
    {
        if (paused) player.pause();
        else if (path !== "") player.play();
    }
    function ready()
    {
        if (player.hasVideo && player.playbackState === MediaPlayer.PlayingState)
            ServiceAppearance.videoReady(path);
    }
    onPausedChanged: playback()
    onPathChanged: { revealed = false; reveal.restart(); }
    Component.onCompleted: { reveal.restart(); playback(); }
    Timer
    {
        id: reveal
        interval: Config.animationsEnabled && Config.wallpaperTransition !== "none" ? 1200 : 0
        onTriggered: wallpaper.revealed = true
    }
    VideoOutput { id: output; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
    MediaPlayer
    {
        id: player
        objectName: "wallpaperVideoPlayer"
        source: ServiceAppearance.fileUrl(wallpaper.path)
        videoOutput: output
        activeAudioTrack: -1
        loops: MediaPlayer.Infinite
        onSourceChanged: wallpaper.playback()
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) wallpaper.playback()
        onPlaybackStateChanged: wallpaper.ready()
        onHasVideoChanged: wallpaper.ready()
        onErrorOccurred: (error, message) => ServiceAppearance.videoFailed(wallpaper.path, message)
    }
}
