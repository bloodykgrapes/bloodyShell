pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton
{
    id: serviceAudio

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    property real pendingVolume: -1
    property real pendingMicVolume: -1

    function describe(node)
    {
        if (!node) return "";
        return node.nickname || node.description || node.name || "";
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property bool hasSink: sink !== null
    readonly property bool hasSource: source !== null

    readonly property real   volume: sink && sink.audio ? Math.min(1, sink.audio.volume) : 0
    readonly property bool   muted: sink && sink.audio ? sink.audio.muted : false
    readonly property string sinkName: describe(sink)

    readonly property real   micVolume: source && source.audio ? Math.min(1, source.audio.volume) : 0
    readonly property bool   micMuted: source && source.audio ? source.audio.muted : false
    readonly property string sourceName: describe(source)

    readonly property var sinks:   (Pipewire.nodes.values || []).filter(n => n && n.audio && n.isSink && !n.isStream)
    readonly property var sources: (Pipewire.nodes.values || []).filter(n => n && n.audio && !n.isSink && !n.isStream)

    readonly property var streams: (Pipewire.nodes.values || []).filter(n => n && n.audio && n.isStream && n.isSink)
    PwObjectTracker { objects: serviceAudio.streams }

    function nodeById(id) { return (Pipewire.nodes.values || []).find(n => n && n.id === id) || null }

    function appIdOf(n)
    {
        if (!n) return "";
        const p = n.properties;
        return p["application.icon-name"] || String(p["application.process.binary"] || "").replace(/-bin$/, "") || p["application.name"] || n.name;
    }
    function streamName(n) { return n ? ServiceApplications.appName(appIdOf(n), n.properties["application.name"] || describe(n)) : "" }
    function streamIcon(n) { return n ? ServiceApplications.iconFor(appIdOf(n)) : "" }

    function shortName(node)
    {
        const full = describe(node);
        const cut = full.replace(/\s+(analog|digital)\s+stereo.*$/i, "").replace(/\s*\(.*\)\s*$/, "").trim();
        return cut || full;
    }

    function setSink(node)   { if (node) Pipewire.preferredDefaultAudioSink = node }
    function setSource(node) { if (node) Pipewire.preferredDefaultAudioSource = node }

    function isHeadphones(node)
    {
        const text = (describe(node) + " " + (node ? node.name : "")).toLowerCase();
        return /head(phone|set)|earbud|airpod|bluez/.test(text);
    }

    function setVolume(value)
    {
        if (!hasSink || !sink.audio || !Number.isFinite(Number(value))) return;
        pendingVolume = Math.max(0, Math.min(1, Number(value)));
        sink.audio.volume = pendingVolume;
        pendingClear.restart();
    }

    function changeVolume(delta)
    {
        const base = pendingVolume >= 0 ? pendingVolume : volume;
        setVolume(Math.round((base + delta) * 100) / 100);
    }

    function setMicVolume(value)
    {
        if (!hasSource || !source.audio || !Number.isFinite(Number(value))) return;
        pendingMicVolume = Math.max(0, Math.min(1, Number(value)));
        source.audio.volume = pendingMicVolume;
        pendingClear.restart();
    }

    function toggleMute()    { if (hasSink && sink.audio) sink.audio.muted = !sink.audio.muted }
    function toggleMicMute() { if (hasSource && source.audio) source.audio.muted = !source.audio.muted }

    Timer
    {
        id: pendingClear
        interval: 250
        onTriggered: { serviceAudio.pendingVolume = -1; serviceAudio.pendingMicVolume = -1 }
    }
}
