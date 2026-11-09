pragma ComponentBehavior: Bound

import QtQuick

import "../../../src/ModelSync.js" as ModelSync
import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"

Menu
{
    id: menuVolume

    implicitWidth: 320

    ListModel { id: apps }
    function syncApps() { ModelSync.sync(apps, ServiceAudio.streams.map(n => ({ nodeId: n.id })), "nodeId") }
    Component.onCompleted: syncApps()
    Connections { target: ServiceAudio; function onStreamsChanged() { menuVolume.syncApps() } }

    RevealSection
    {
        shown: menuVolume.presented
        order: 0

        MenuLabel { text: Tr.tr("common.output") }

        MenuSlider
        {
            icon: Icon.volume
            value: ServiceAudio.volume
            muted: ServiceAudio.muted
            available: ServiceAudio.hasSink

            onMoved: value => ServiceAudio.setVolume(value)
            onIconClicked: ServiceAudio.toggleMute()
        }

        DeviceCards
        {
            nodes: ServiceAudio.sinks
            current: ServiceAudio.sink
            fallbackIcon: Icon.speaker
            onChosen: node => ServiceAudio.setSink(node)
        }
    }

    RevealSection
    {
        shown: menuVolume.presented
        order: 1

        MenuSeparator { visible: apps.count > 0 }
        MenuLabel { text: Tr.tr("common.applications"); visible: apps.count > 0 }

        MenuList
        {
            model: apps
            opening: menuVolume.opening
            maxHeight: Math.round(200 * Config.themeScale)

            delegate: MenuSlider
            {
                id: appRow

                required property int nodeId
                readonly property var node: ServiceAudio.nodeById(nodeId)
                readonly property var audio: node ? node.audio : null

                width: ListView.view ? ListView.view.rowWidth : 300
                appIcon: ServiceAudio.streamIcon(node)
                icon: Icon.volume
                label: ServiceAudio.streamName(node)
                value: audio ? Math.min(1, audio.volume) : 0
                muted: audio ? audio.muted : false

                onMoved: value => { if (appRow.audio) appRow.audio.volume = value }
                onIconClicked: if (appRow.audio) appRow.audio.muted = !appRow.audio.muted
            }
        }
    }

    RevealSection
    {
        shown: menuVolume.presented
        order: 2

        MenuSeparator { }

        MenuLabel { text: Tr.tr("common.input") }

        MenuSlider
        {
            icon: ServiceAudio.micMuted ? Icon.microphoneOff : Icon.microphone
            value: ServiceAudio.micVolume
            muted: ServiceAudio.micMuted
            available: ServiceAudio.hasSource

            onMoved: value => ServiceAudio.setMicVolume(value)
            onIconClicked: ServiceAudio.toggleMicMute()
        }

        DeviceCards
        {
            nodes: ServiceAudio.sources
            current: ServiceAudio.source
            fallbackIcon: Icon.microphone
            onChosen: node => ServiceAudio.setSource(node)
        }

        MenuLabel { hint: true; text: Tr.tr("menu.volume.noAudioDevices"); visible: !ServiceAudio.hasSink && !ServiceAudio.hasSource }
    }

    component DeviceCards: Flow
    {
        id: cards

        property var    nodes: []
        property var    current: null
        property string fallbackIcon: ""
        signal chosen(var node)

        visible: nodes.length > 1
        width: parent ? parent.width : 300
        leftPadding: 4
        rightPadding: 4
        topPadding: 2
        bottomPadding: 4
        spacing: 6

        Repeater
        {
            model: cards.nodes

            Rectangle
            {
                id: card

                required property var modelData
                readonly property bool active: modelData === cards.current

                width: Math.min(cardRow.implicitWidth + 22, cards.width - 8)
                height: 30
                radius: 15
                color: area.pressed ? Theme.colorPressed
                     : active ? Theme.colorChosen
                     : area.containsMouse ? Theme.colorHoverStrong : Theme.colorField
                Tint on color {}

                scale: area.pressed ? 0.95 : area.containsMouse ? 1.04 : 1
                Spring on scale {}

                Row
                {
                    id: cardRow
                    anchors.centerIn: parent
                    spacing: 6

                    ShellIcon
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: ServiceAudio.isHeadphones(card.modelData) ? Icon.headphones : cards.fallbackIcon
                        size: 14
                        opacity: card.active ? 1 : 0.75
                    }
                    ShellText
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, cards.width - 60)
                        label: ServiceAudio.shortName(card.modelData)
                        size: 11
                        color: card.active ? Theme.text1 : Theme.text2
                        Tint on color {}
                    }
                }

                MouseArea
                {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cards.chosen(card.modelData)
                }

                Accessible.role: Accessible.RadioButton
                Accessible.name: ServiceAudio.describe(card.modelData)
                Accessible.checked: card.active
            }
        }
    }
}
