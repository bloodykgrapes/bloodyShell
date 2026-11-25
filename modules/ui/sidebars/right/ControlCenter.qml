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
    spacing: 8

    SidebarSection
    {
        host: controlCenter.host
        order: 0
        Row
        {
            width: parent.width
            spacing: 6
            MenuToggle
            {
                objectName: "controlWifi"
                width: (parent.width - parent.spacing) / 2
                height: implicitHeight
                text: ServiceNetwork.connectedWiFi && ServiceNetwork.ssid !== "" ? ServiceNetwork.ssid : Tr.tr("sidebar.wifi")
                icon: checked ? Icon.networkWiFiON : Icon.networkWiFiOFF
                checked: ServiceNetwork.enabledWiFi
                available: ServiceNetwork.hasWiFi && ServiceNetwork.enabledWiFiHardware
                onToggled: value => ServiceNetwork.setWifiEnabled(value)
            }
            MenuToggle
            {
                objectName: "controlBluetooth"
                width: (parent.width - parent.spacing) / 2
                height: implicitHeight
                text: Tr.tr("common.bluetooth")
                icon: Icon.bluetooth
                checked: ServiceBluetooth.enabled
                available: ServiceBluetooth.available
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
            spacing: 6
            MenuSlider
            {
                objectName: "controlVolume"
                width: (parent.width - parent.spacing) / 2
                height: implicitHeight
                text: Tr.tr("common.volume")
                icon: Icon.volume
                value: ServiceAudio.pendingVolume >= 0 ? ServiceAudio.pendingVolume : ServiceAudio.volume
                muted: ServiceAudio.muted
                available: ServiceAudio.hasSink
                onMoved: value => ServiceAudio.setVolume(value)
                onIconClicked: ServiceAudio.toggleMute()
            }
            MenuSlider
            {
                objectName: "controlMicrophone"
                width: (parent.width - parent.spacing) / 2
                height: implicitHeight
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
        visible: ServiceDisplay.brightnessAvailable
        MenuSlider
        {
            objectName: "controlBrightness"
            width: parent.width
            height: implicitHeight
            iconAction: false
            text: Tr.tr("sidebar.brightness")
            icon: Icon.brightness
            value: ServiceDisplay.brightnessPending >= 0 ? ServiceDisplay.brightnessPending / 100
                 : ServiceDisplay.brightnessRunning >= 0 ? ServiceDisplay.brightnessRunning / 100 : ServiceDisplay.brightness
            onMoved: value => ServiceDisplay.setBrightness(value)
        }
    }
    SidebarSection
    {
        id: mediaSection
        host: controlCenter.host
        order: 3
        topPadding: 6
        readonly property bool hasPlayer: ServiceMedia.available
        visible: hasPlayer || mediaCard.height > 0.5
        ClippingRectangle
        {
            id: mediaCard
            objectName: "controlMedia"
            width: parent.width
            height: mediaSection.hasPlayer && media.item ? media.item.implicitHeight + 16 : 0
            radius: Theme.menuControlRadius
            color: Theme.menuControlBackground
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
