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

    Column
    {
        width: parent.width
        spacing: 12

        SettingsRowGroup
        {
            title: Tr.tr("common.output")

            SettingsRow
            {
                label: Tr.tr("settings.sound.outputDevice")

                SettingsDropdown
                {
                    preferredWidth: 300
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

                Row
                {
                    spacing: 10

                    SettingsSlider
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        preferredWidth: 240
                        opacity: ServiceAudio.muted ? 0.45 : 1
                        value: ServiceAudio.volume
                        onMoved: value => ServiceAudio.setVolume(value)
                    }
                    Button
                    {
                        iconOnly: true
                        objectName: "outputMute"
                        anchors.verticalCenter: parent.verticalCenter
                        icon: pageSound.volumeIcon(ServiceAudio.volume, ServiceAudio.muted)
                        iconSize: 14
                        text: Tr.tr(ServiceAudio.muted ? "settings.sound.unmuteOutput" : "settings.sound.muteOutput")
                        Accessible.checkable: true
                        Accessible.checked: ServiceAudio.muted
                        onClicked: ServiceAudio.toggleMute()
                    }
                }
            }
        }

        SettingsRowGroup
        {
            Repeater
            {
                model: pageSound.streams

                SettingsRow
                {
                    id: streamRow
                    wrapText: false

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
                            preferredWidth: 240
                            opacity: streamRow.audio && streamRow.audio.muted ? 0.45 : 1
                            value: streamRow.audio ? Math.min(1, streamRow.audio.volume) : 0
                            onMoved: value => { if (streamRow.audio) streamRow.audio.volume = value }
                        }
                        Button
                        {
                            iconOnly: true
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
    }

    Column
    {
        width: parent.width
        spacing: 12

        SettingsRowGroup
        {
            title: Tr.tr("common.input")

            SettingsRow
            {
                label: Tr.tr("settings.sound.inputDevice")

                SettingsDropdown
                {
                    preferredWidth: 300
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

                Row
                {
                    spacing: 10

                    SettingsSlider
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        preferredWidth: 240
                        opacity: ServiceAudio.micMuted ? 0.45 : 1
                        value: ServiceAudio.micVolume
                        onMoved: value => ServiceAudio.setMicVolume(value)
                    }
                    Button
                    {
                        iconOnly: true
                        objectName: "inputMute"
                        anchors.verticalCenter: parent.verticalCenter
                        icon: ServiceAudio.micMuted ? Icon.microphoneOff : Icon.microphone
                        iconSize: 14
                        text: Tr.tr(ServiceAudio.micMuted ? "settings.sound.unmuteMicrophone" : "settings.sound.muteMicrophone")
                        Accessible.checkable: true
                        Accessible.checked: ServiceAudio.micMuted
                        onClicked: ServiceAudio.toggleMicMute()
                    }
                }
            }
        }

        SettingsRowGroup
        {
            Repeater
            {
                model: pageSound.recording

                SettingsRow
                {
                    id: recordRow
                    wrapText: false

                    required property var modelData
                    readonly property var audio: modelData.audio

                    icon: pageSound.streamIcon(modelData)
                    label: pageSound.streamName(modelData)
                    description: recordRow.audio && recordRow.audio.muted ? Tr.tr("settings.sound.appMuted") : pageSound.mediaName(modelData)

                    Button
                    {
                        iconOnly: true
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
}
