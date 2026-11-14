pragma Singleton

import QtQuick
import Quickshell

import "../core"

Singleton
{
    readonly property var streams: ServiceCompositor.captureStreams.filter(stream => stream.active)
    readonly property bool active: streams.length > 0
    readonly property var outputs: Array.from(new Set(streams.map(stream => stream.output).filter(Boolean)))
    readonly property string detail: outputs.length > 0 ? outputs.join(" · ")
        : Tr.tr("recording.streams").arg(streams.length)
}
