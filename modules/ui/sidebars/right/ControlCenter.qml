pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"
import "../components"

Column
{
    id: controlCenter
    required property Item host
    property bool active: false
    width: parent ? parent.width : implicitWidth
    spacing: 14

    SidebarSection
    {
        host: controlCenter.host
        order: 0
        Row
        {
            width: parent.width
            spacing: 12
            ControlToggle
            {
                objectName: "controlWifi"
                width: (parent.width - parent.spacing) / 2
                height: implicitHeight
                text: Tr.tr("sidebar.wifi")
                icon: checked ? Icon.networkWiFiON : Icon.networkWiFiOFF
                checked: ServiceNetwork.enabledWiFi
                available: ServiceNetwork.hasWiFi && ServiceNetwork.enabledWiFiHardware
                subtitle: checked ? (ServiceNetwork.connectedWiFi ? ServiceNetwork.ssid : Tr.tr("common.enabled")) : Tr.tr("common.off")
                onToggled: value => ServiceNetwork.setWifiEnabled(value)
            }
            ControlToggle
            {
                objectName: "controlBluetooth"
                width: (parent.width - parent.spacing) / 2
                height: implicitHeight
                text: Tr.tr("common.bluetooth")
                icon: Icon.bluetooth
                checked: ServiceBluetooth.enabled
                available: ServiceBluetooth.available
                subtitle: checked ? Tr.tr(ServiceBluetooth.connected ? "common.connected" : "common.enabled") : Tr.tr("common.off")
                onToggled: value => ServiceBluetooth.setEnabled(value)
            }
        }
    }
    SidebarSection
    {
        host: controlCenter.host
        order: 1
        Row
        {
            width: parent.width
            spacing: 12
            height: 36
            ControlSlider
            {
                objectName: "controlVolume"
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                text: Tr.tr("common.volume")
                icon: Icon.volume
                value: ServiceAudio.pendingVolume >= 0 ? ServiceAudio.pendingVolume : ServiceAudio.volume
                muted: ServiceAudio.muted
                available: ServiceAudio.hasSink
                onMoved: value => ServiceAudio.setVolume(value)
                onIconClicked: ServiceAudio.toggleMute()
            }
            ControlSlider
            {
                objectName: "controlMicrophone"
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                text: Tr.tr("sidebar.microphone")
                icon: muted ? Icon.microphoneOff : Icon.microphone
                value: ServiceAudio.pendingMicVolume >= 0 ? ServiceAudio.pendingMicVolume : ServiceAudio.micVolume
                muted: ServiceAudio.micMuted
                available: ServiceAudio.hasSource
                onMoved: value => ServiceAudio.setMicVolume(value)
                onIconClicked: ServiceAudio.toggleMicMute()
            }
        }
    }
    SidebarSection
    {
        host: controlCenter.host
        order: 2
        ControlSlider
        {
            objectName: "controlBrightness"
            width: parent.width
            height: implicitHeight
            iconAction: false
            text: Tr.tr("sidebar.brightness")
            icon: Icon.brightness
            value: ServiceDisplay.brightnessPending >= 0 ? ServiceDisplay.brightnessPending / 100
                 : ServiceDisplay.brightnessRunning >= 0 ? ServiceDisplay.brightnessRunning / 100 : ServiceDisplay.brightness
            available: ServiceDisplay.brightnessAvailable
            onMoved: value => ServiceDisplay.setBrightness(value)
        }
    }
    SidebarSection
    {
        id: mediaSection
        host: controlCenter.host
        order: 3
        readonly property bool hasPlayer: ServiceMedia.available
        visible: hasPlayer || mediaCard.height > 0.5
        ClippingRectangle
        {
            id: mediaCard
            objectName: "controlMedia"
            width: parent.width
            height: mediaSection.hasPlayer && media.item ? media.item.implicitHeight + 16 : 0
            radius: 22
            color: Theme.colorField
            opacity: mediaSection.hasPlayer ? 1 : 0
            Glide on height { duration: Theme.animationDurationMorph }
            Smooth on opacity {}

            Loader
            {
                id: media
                objectName: "controlMediaContent"
                x: 8; y: 8
                width: parent.width - 16
                active: controlCenter.active
                source: active ? Qt.resolvedUrl("../../bar/menus/MenuMedia.qml") : ""
            }
        }
    }
}
