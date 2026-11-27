pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

import "../core"

Singleton
{
    readonly property var streams: ServiceCompositor.captureStreams.filter(stream => stream.active)
    readonly property bool active: streams.length > 0
    readonly property bool cameraActive: Config.islandCameraIndicator && (Pipewire.links?.values ?? []).some(link =>
        link?.state === PwLinkState.Active && link.target?.isStream && isCameraSource(link.source))
    readonly property var outputs: Array.from(new Set(streams.map(stream => stream.output).filter(Boolean)))
    readonly property string detail: outputs.length > 0 ? outputs.join(" · ")
        : Tr.tr("recording.streams").arg(streams.length)

    function isCameraSource(source)
    {
        if (!source || source.isStream || source.isSink || !(source.type & PwNodeType.Video)) return false;
        const properties = source.properties ?? {};
        return properties["media.role"] === "Camera"
            || /^(v4l2|libcamera)([._-]|$)/i.test(properties["device.api"] || source.name);
    }
}
