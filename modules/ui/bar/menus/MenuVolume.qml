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
    contentAnimatesHeight: true
    property Item openDeviceList: null

    function expandDevices(dropdown)
    {
        if (openDeviceList && openDeviceList !== dropdown) openDeviceList.open = false;
        openDeviceList = dropdown;
    }

    ListModel { id: apps }
    function syncApps() { ModelSync.sync(apps, ServiceAudio.streams.map(n => ({ nodeId: n.id })), "nodeId") }
    Component.onCompleted: syncApps()
    Connections { target: ServiceAudio; function onStreamsChanged() { menuVolume.syncApps() } }

    DeviceSection
    {
        order: 0
        caption: Tr.tr("common.output")
        sliderLabel: Tr.tr("common.volume")
        icon: Icon.volume
        value: ServiceAudio.pendingVolume >= 0 ? ServiceAudio.pendingVolume : ServiceAudio.volume
        muted: ServiceAudio.muted
        available: ServiceAudio.hasSink
        nodes: ServiceAudio.sinks
        current: ServiceAudio.sink
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

            delegate: MenuSlider
            {
                id: appRow

                required property int nodeId
                readonly property var node: ServiceAudio.nodeById(nodeId)
                readonly property var audio: node ? node.audio : null

                objectName: "applicationVolume-" + nodeId
                width: ListView.view ? ListView.view.rowWidth : 300
                height: 40
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
        sliderLabel: Tr.tr("sidebar.microphone")
        icon: ServiceAudio.micMuted ? Icon.microphoneOff : Icon.microphone
        value: ServiceAudio.pendingMicVolume >= 0 ? ServiceAudio.pendingMicVolume : ServiceAudio.micVolume
        muted: ServiceAudio.micMuted
        available: ServiceAudio.hasSource
        nodes: ServiceAudio.sources
        current: ServiceAudio.source
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
        property string sliderLabel: ""
        property string icon: ""
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
        MenuSlider
        {
            objectName: section.order === 0 ? "outputVolume" : "inputVolume"
            width: parent.width
            height: 40
            text: section.sliderLabel
            icon: section.icon
            value: section.value
            muted: section.muted
            available: section.available
            onMoved: value => section.moved(value)
            onIconClicked: section.iconClicked()
        }
        MenuDropdown
        {
            id: devices
            objectName: "audioDevice-" + section.order
            width: parent.width
            presented: menuVolume.presented
            visible: entries.length > 0
            enabled: entries.length > 0
            options: section.nodes.map(node => ({label: ServiceAudio.describe(node), value: node.id}))
            current: section.current ? section.current.id : -1
            onOpenChanged: if (open) menuVolume.expandDevices(devices)
            onSelected: value => section.chosen(section.nodes.find(node => String(node.id) === String(value)) || null)
        }
    }
}
