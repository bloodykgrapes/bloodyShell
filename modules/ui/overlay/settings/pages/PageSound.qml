import QtQuick
import Quickshell.Services.Pipewire

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageSound

    title: Tr.tr("common.sound")
    subtitle: Tr.tr("settings.sound.description")

    readonly property var streams: ServiceAudio.streams
    readonly property var recording: (Pipewire.nodes.values || []).filter(n => n && n.audio && n.isStream && !n.isSink)

    function streamName(n) { return ServiceAudio.streamName(n) }
    function streamIcon(n) { return ServiceAudio.streamIcon(n) }

    function mediaName(n) { const m = String(n.properties["media.name"] || "").trim(); return m.length > 1 ? m : "" }

    function volumeIcon(v, muted)
    {
        if (muted || v === 0) return Icon.path + "volume_muted.svg";
        return Icon.path + "volume_" + (v < 0.33 ? 1 : v < 0.66 ? 2 : 3) + ".svg";
    }

    function nodeOptions(nodes) { return nodes.map(n => ({ label: ServiceAudio.describe(n), value: n.id })) }
    function nodeById(nodes, id) { return nodes.find(n => n.id === id) || null }

    PwObjectTracker { objects: pageSound.recording }

    SettingsGroup
    {
        title: Tr.tr("common.output")

        SettingsRow
        {
            label: Tr.tr("settings.sound.outputDevice")

            SettingsCombo
            {
                width: 300
                enabled: ServiceAudio.sinks.length > 0
                placeholderText: Tr.tr("settings.sound.noOutputDevices")
                options: pageSound.nodeOptions(ServiceAudio.sinks)
                current: ServiceAudio.sink ? ServiceAudio.sink.id : -1
                onSelected: value => ServiceAudio.setSink(pageSound.nodeById(ServiceAudio.sinks, value))
            }
        }
        SettingsRow
        {
            label: Tr.tr("common.volume")
            enabled: ServiceAudio.hasSink

            SettingsSlider
            {
                width: 300
                value: ServiceAudio.volume
                onMoved: value => ServiceAudio.setVolume(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.sound.muteOutput")
            enabled: ServiceAudio.hasSink
            Toggle { checked: ServiceAudio.muted; onToggled: ServiceAudio.toggleMute() }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.input")

        SettingsRow
        {
            label: Tr.tr("settings.sound.inputDevice")

            SettingsCombo
            {
                width: 300
                enabled: ServiceAudio.sources.length > 0
                placeholderText: Tr.tr("settings.sound.noInputDevices")
                options: pageSound.nodeOptions(ServiceAudio.sources)
                current: ServiceAudio.source ? ServiceAudio.source.id : -1
                onSelected: value => ServiceAudio.setSource(pageSound.nodeById(ServiceAudio.sources, value))
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.sound.microphoneLevel")
            enabled: ServiceAudio.hasSource

            SettingsSlider
            {
                width: 300
                value: ServiceAudio.micVolume
                onMoved: value => ServiceAudio.setMicVolume(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.sound.muteMicrophone")
            enabled: ServiceAudio.hasSource
            Toggle { checked: ServiceAudio.micMuted; onToggled: ServiceAudio.toggleMicMute() }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.sound.playbackApps")

        Repeater
        {
            model: pageSound.streams

            SettingsRow
            {
                id: streamRow

                required property var modelData
                readonly property var audio: modelData.audio

                icon: pageSound.streamIcon(modelData)
                label: pageSound.streamName(modelData)
                description: pageSound.mediaName(modelData)

                Row
                {
                    spacing: 10

                    SettingsSlider
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 240
                        opacity: streamRow.audio && streamRow.audio.muted ? 0.45 : 1
                        value: streamRow.audio ? Math.min(1, streamRow.audio.volume) : 0
                        onMoved: value => { if (streamRow.audio) streamRow.audio.volume = value }
                    }
                    SettingsIconButton
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: pageSound.volumeIcon(streamRow.audio ? streamRow.audio.volume : 0, streamRow.audio ? streamRow.audio.muted : false)
                        iconSize: 14
                        onClicked: if (streamRow.audio) streamRow.audio.muted = !streamRow.audio.muted
                    }
                }
            }
        }
        SettingsRow
        {
            visible: pageSound.streams.length === 0
            label: Tr.tr("common.noMedia")
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.sound.recordingApps")

        Repeater
        {
            model: pageSound.recording

            SettingsRow
            {
                id: recordRow

                required property var modelData
                readonly property var audio: modelData.audio

                icon: pageSound.streamIcon(modelData)
                label: pageSound.streamName(modelData)
                description: recordRow.audio && recordRow.audio.muted ? Tr.tr("settings.sound.appMuted") : pageSound.mediaName(modelData)

                SettingsIconButton
                {
                    icon: recordRow.audio && recordRow.audio.muted ? Icon.microphoneOff : Icon.microphone
                    iconSize: 14
                    onClicked: if (recordRow.audio) recordRow.audio.muted = !recordRow.audio.muted
                }
            }
        }
        SettingsRow
        {
            visible: pageSound.recording.length === 0
            label: Tr.tr("settings.sound.noActiveApps")
        }
    }
}
