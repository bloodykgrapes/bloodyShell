pragma ComponentBehavior: Bound

import QtQuick

import "../../../src/ModelSync.js" as ModelSync
import "../../../common"
import "../../../core"
import "../../../services"

Menu
{
    id: menuVolume

    implicitWidth: 320
    spacing: 8

    ListModel { id: apps }
    function syncApps() { ModelSync.sync(apps, ServiceAudio.streams.map(n => ({ nodeId: n.id })), "nodeId") }
    Component.onCompleted: syncApps()
    Connections { target: ServiceAudio; function onStreamsChanged() { menuVolume.syncApps() } }

    DeviceSection
    {
        order: 0
        caption: Tr.tr("common.output")
        icon: Icon.volume
        value: ServiceAudio.pendingVolume >= 0 ? ServiceAudio.pendingVolume : ServiceAudio.volume
        muted: ServiceAudio.muted
        available: ServiceAudio.hasSink
        nodes: ServiceAudio.sinks
        current: ServiceAudio.sink
        fallbackIcon: Icon.speaker
        onMoved: value => ServiceAudio.setVolume(value)
        onIconClicked: ServiceAudio.toggleMute()
        onChosen: node => ServiceAudio.setSink(node)
    }

    RevealSection
    {
        shown: menuVolume.presented
        order: 1
        visible: apps.count > 0
        spacing: 4

        MenuLabel { heading: true; text: Tr.tr("common.applications") }

        MenuList
        {
            model: apps
            opening: menuVolume.opening
            maxHeight: 3 * 48
            spacing: 4

            delegate: ControlSlider
            {
                id: appRow

                required property int nodeId
                readonly property var node: ServiceAudio.nodeById(nodeId)
                readonly property var audio: node ? node.audio : null

                objectName: "applicationVolume-" + nodeId
                width: ListView.view ? ListView.view.rowWidth : 300
                height: 44
                appIcon: ServiceAudio.streamIcon(node)
                icon: Icon.volume
                text: ServiceAudio.streamName(node)
                value: audio ? Math.min(1, audio.volume) : 0
                muted: audio ? audio.muted : false
                available: audio !== null

                onMoved: value => { if (appRow.audio) appRow.audio.volume = value }
                onIconClicked: if (appRow.audio) appRow.audio.muted = !appRow.audio.muted
            }
        }
    }

    DeviceSection
    {
        order: 2
        caption: Tr.tr("common.input")
        icon: ServiceAudio.micMuted ? Icon.microphoneOff : Icon.microphone
        value: ServiceAudio.pendingMicVolume >= 0 ? ServiceAudio.pendingMicVolume : ServiceAudio.micVolume
        muted: ServiceAudio.micMuted
        available: ServiceAudio.hasSource
        nodes: ServiceAudio.sources
        current: ServiceAudio.source
        fallbackIcon: Icon.microphone
        onMoved: value => ServiceAudio.setMicVolume(value)
        onIconClicked: ServiceAudio.toggleMicMute()
        onChosen: node => ServiceAudio.setSource(node)
    }

    RevealSection
    {
        shown: menuVolume.presented
        order: 3
        visible: !ServiceAudio.hasSink && !ServiceAudio.hasSource
        MenuLabel { hint: true; text: Tr.tr("menu.volume.noAudioDevices") }
    }

    component DeviceSection: RevealSection
    {
        id: section

        property string caption: ""
        property string icon: ""
        property string fallbackIcon: ""
        property real value: 0
        property bool muted: false
        property bool available: true
        property var nodes: []
        property var current: null
        signal moved(real value)
        signal iconClicked()
        signal chosen(var node)

        shown: menuVolume.presented
        spacing: 4

        MenuLabel { heading: true; text: section.caption }
        ControlSlider
        {
            objectName: section.order === 0 ? "outputVolume" : "inputVolume"
            width: parent.width
            height: 44
            text: ServiceAudio.shortName(section.current) || section.caption
            icon: section.icon
            value: section.value
            muted: section.muted
            available: section.available
            onMoved: value => section.moved(value)
            onIconClicked: section.iconClicked()
        }
        MenuList
        {
            model: section.nodes.length > 1 ? section.nodes : []
            opening: menuVolume.opening
            maxHeight: 3 * 48
            spacing: 4

            delegate: MenuRow
            {
                required property var modelData

                filled: true
                selected: section.current !== null && modelData.id === section.current.id
                icon: ServiceAudio.isHeadphones(modelData) ? Icon.headphones : section.fallbackIcon
                text: ServiceAudio.shortName(modelData)
                subtitle: ServiceAudio.describe(modelData) !== text ? ServiceAudio.describe(modelData) : ""
                onClicked: if (!selected) section.chosen(modelData)

                Accessible.role: Accessible.RadioButton
                Accessible.checkable: true
                Accessible.checked: selected
            }
        }
    }
}
