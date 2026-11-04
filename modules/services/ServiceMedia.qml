pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

import "../core"

Singleton
{
    id: serviceMedia

    readonly property var players: Mpris.players.values

    property string chosen: ""
    property string lastPlaying: ""

    readonly property var player:
    {
        const list = players;
        if (list.length === 0) return null;
        const by = name => name !== "" ? list.find(p => p.dbusName === name) : undefined;
        return by(chosen) || list.find(p => p.isPlaying) || by(lastPlaying) || list[0];
    }

    Instantiator
    {
        model: serviceMedia.players
        delegate: Connections
        {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { if (modelData.isPlaying) serviceMedia.lastPlaying = modelData.dbusName }
        }
    }

    function choose(p) { if (p) chosen = p.dbusName }

    readonly property bool   available: player !== null
    readonly property bool   playing: player ? player.isPlaying : false
    readonly property string title: player ? (player.trackTitle || player.identity || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string album: player ? (player.trackAlbum || "") : ""
    readonly property string art: player ? (player.trackArtUrl || "") : ""
    readonly property string app: player ? (player.identity || "") : ""

    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0
    readonly property bool canSeek: player ? player.canSeek && length > 0 : false

    function toggle()   { if (player && player.canTogglePlaying) player.togglePlaying() }
    function next()     { if (player && player.canGoNext) player.next() }
    function previous() { if (player && player.canGoPrevious) player.previous() }
    function raise()    { if (player && player.canRaise) player.raise() }
    function seekTo(fraction)
    {
        if (!canSeek) return;
        player.position = Math.max(0, Math.min(1, fraction)) * length;
    }
    function toggleShuffle() { if (player && player.shuffleSupported) player.shuffle = !player.shuffle }
    function cycleLoop()
    {
        if (!player || !player.loopSupported) return;
        player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                         : player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                         : MprisLoopState.None;
    }

    function time(seconds)
    {
        const s = Math.max(0, Math.floor(seconds || 0));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
        const two = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + two(m) + ":" + two(r) : m + ":" + two(r);
    }

    property var positionClients: []
    property var visualizerClients: []
    readonly property int positionUsers: positionClients.length
    readonly property int visualizerUsers: visualizerClients.length

    function setPositionActive(client, active)
    {
        const present = positionClients.includes(client);
        if (present === active) return;
        positionClients = active ? positionClients.concat([client]) : positionClients.filter(c => c !== client);
        if (active && positionClients.length === 1 && player && player.positionSupported) player.positionChanged();
    }

    function setVisualizerActive(client, active)
    {
        const present = visualizerClients.includes(client);
        if (present === active) return;
        visualizerClients = active ? visualizerClients.concat([client]) : visualizerClients.filter(c => c !== client);
    }

    Timer
    {
        interval: 1000
        repeat: true
        running: serviceMedia.positionUsers > 0 && serviceMedia.playing && serviceMedia.player !== null && serviceMedia.player.positionSupported
        onTriggered: serviceMedia.player.positionChanged()
    }

    readonly property int bars: 28
    property var levels: []
    readonly property bool visualizerRunning: visualizerUsers > 0 && playing && Config.animationsEnabled
    property bool cavaMissing: false

    readonly property string cavaConfig: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/bloodyShell-cava.conf"

    Process
    {
        id: cava
        running: serviceMedia.visualizerRunning && !serviceMedia.cavaMissing
        command: ["sh", "-c",
            "command -v cava > /dev/null || exit 127; "
            + "printf '[general]\\nbars = %s\\nframerate = 30\\nsleep_timer = 1\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\n"
            + "data_format = ascii\\nascii_max_range = 1000\\nbar_delimiter = 59\\nframe_delimiter = 10\\n[smoothing]\\nnoise_reduction = 70\\n' "
            + "\"$1\" > \"$2\" && exec cava -p \"$2\"", "sh", String(serviceMedia.bars), serviceMedia.cavaConfig]
        stdout: SplitParser
        {
            onRead: line =>
            {
                if (!serviceMedia.visualizerRunning) return;
                const values = line.split(";");
                const out = [];
                for (let i = 0; i < serviceMedia.bars; i++) out.push(Math.min(1, (parseInt(values[i], 10) || 0) / 1000));
                if (out.length !== serviceMedia.levels.length || out.some((value, index) => value !== serviceMedia.levels[index])) serviceMedia.levels = out;
            }
        }
        onExited: code => { if (code === 127) serviceMedia.cavaMissing = true }
    }

    Timer
    {
        interval: 90
        repeat: true
        running: serviceMedia.visualizerRunning && serviceMedia.cavaMissing
        onTriggered:
        {
            const out = [];
            const t = Date.now() / 1000;
            for (let i = 0; i < serviceMedia.bars; i++)
            {
                const tilt = 1 - i / serviceMedia.bars * 0.55;
                const wave = 0.5 + 0.5 * Math.sin(t * (2.1 + i * 0.37) + i * 1.7);
                out.push(Math.max(0.04, tilt * (0.25 + 0.6 * wave * (0.6 + 0.4 * Math.random()))));
            }
            serviceMedia.levels = out;
        }
    }
    onVisualizerRunningChanged: if (!visualizerRunning) levels = []
}
