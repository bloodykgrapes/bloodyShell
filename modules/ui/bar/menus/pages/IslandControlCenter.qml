pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

import "../../../../animations"
import "../../../../common"
import "../../../../core"
import "../../../../services"

Column
{
    id: controlCenter

    width: parent ? parent.width : 400
    spacing: 8
    readonly property real wallpaperWidth: (width - spacing) * 0.58

    function openOverlay(name, settingsID)
    {
        if (settingsID !== undefined)
        {
            const index = Registry.settingsIndex(settingsID);
            if (index >= 0) OverlayState.settingsPage = index;
        }
        MenuState.close();
        OverlayState.show(name);
    }

    Component.onCompleted: ServiceNotifications.markRead()

    Row
    {
        width: parent.width
        spacing: 8

        WallpaperPreview
        {
            objectName: "islandWallpaper"
            width: controlCenter.wallpaperWidth
            height: 104
            cornerRadius: Theme.menuControlRadius
            onClicked: controlCenter.openOverlay("wallpapers")
        }

        Rectangle
        {
            id: userCard
            objectName: "islandUser"
            width: parent.width - parent.spacing - controlCenter.wallpaperWidth
            height: 104
            radius: Theme.menuControlRadius
            color: userPointer.hovered ? Theme.colorHoverStrong : Theme.menuControlBackground
            Tint on color {}

            HoverHandler { id: userPointer; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: controlCenter.openOverlay("settings", "user") }
            activeFocusOnTab: true
            Keys.onReturnPressed: event => { if (!event.isAutoRepeat) controlCenter.openOverlay("settings", "user"); }
            Keys.onSpacePressed: event => { if (!event.isAutoRepeat) controlCenter.openOverlay("settings", "user"); }
            Accessible.role: Accessible.Button
            Accessible.name: Tr.tr("common.user")
            Accessible.onPressAction: controlCenter.openOverlay("settings", "user")

            ClippingRectangle
            {
                id: avatar
                anchors { top: parent.top; topMargin: 14; horizontalCenter: parent.horizontalCenter }
                width: 46
                height: 46
                radius: 15
                color: Theme.colorField

                Image
                {
                    id: face
                    anchors.fill: parent
                    source: ServiceUser.avatar ? "file://" + ServiceUser.avatar : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(92, 92)
                    asynchronous: true
                    cache: false
                }
                ShellIcon { anchors.centerIn: parent; visible: face.status !== Image.Ready; icon: Icon.user; size: 22 }
            }
            Column
            {
                anchors { top: avatar.bottom; topMargin: 7; left: parent.left; right: parent.right; margins: 8 }
                spacing: 2
                ShellText
                {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    label: ServiceUser.fullName || ServiceUser.user
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    size: 12
                    font.weight: Font.DemiBold
                    color: Theme.text1
                }
                ShellText
                {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    label: "@" + ServiceUser.user
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    size: 10
                    color: Theme.text3
                }
            }
        }
    }


    Row
    {
        id: actions
        width: parent.width
        height: 36
        spacing: controlCenter.spacing

        Button
        {
            objectName: "islandLauncher"
            width: controlCenter.wallpaperWidth
            height: actions.height
            radius: height / 2
            color: Theme.menuControlBackground
            icon: Icon.search
            text: Tr.tr("common.launcher")
            textSize: 11
            onClicked: controlCenter.openOverlay("launcher")
        }

        Row
        {
            id: sessionActions
            width: actions.width - controlCenter.wallpaperWidth - actions.spacing
            spacing: 6

            Repeater
            {
                model: [
                    { name: "settings", label: "common.settings", icon: Icon.settings, action: () => controlCenter.openOverlay("settings") },
                    { name: "lock", label: "power.lock", icon: Icon.userLock, action: () => ServiceLock.lock() },
                    { name: "power", label: "common.power", icon: Icon.computerPowerOff, action: () => controlCenter.openOverlay("power") }
                ]

                Button
                {
                    required property var modelData
                    objectName: "islandAction-" + modelData.name
                    width: (sessionActions.width - 2 * sessionActions.spacing) / 3
                    height: actions.height
                    radius: height / 2
                    text: Tr.tr(modelData.label)
                    icon: modelData.icon
                    iconOnly: true
                    iconSize: 15
                    danger: modelData.name === "power"
                    color: danger ? Qt.tint(Theme.menuControlBackground, Theme.criticalAlpha(0.17)) : Theme.menuControlBackground
                    hoverScale: 1
                    onClicked: modelData.action()
                }
            }
        }
    }

    Row
    {
        width: parent.width
        spacing: 8

        MenuToggle
        {
            objectName: "islandWifi"
            width: (parent.width - parent.spacing) / 2
            text: ServiceNetwork.connectedWiFi && ServiceNetwork.ssid !== "" ? ServiceNetwork.ssid : Tr.tr("common.wifi")
            subtitle: ServiceNetwork.enabledWiFi ? Tr.tr("common.enabled") : Tr.tr("common.disabled")
            icon: checked ? Icon.networkWiFiON : Icon.networkWiFiOFF
            checked: ServiceNetwork.enabledWiFi
            available: ServiceNetwork.hasWiFi && ServiceNetwork.enabledWiFiHardware
            onToggled: value => ServiceNetwork.setWifiEnabled(value)
        }
        MenuToggle
        {
            objectName: "islandBluetooth"
            width: (parent.width - parent.spacing) / 2
            text: Tr.tr("common.bluetooth")
            subtitle: checked ? Tr.tr("common.enabled") : Tr.tr("common.disabled")
            icon: Icon.bluetooth
            checked: ServiceBluetooth.enabled
            available: ServiceBluetooth.available
            onToggled: value => ServiceBluetooth.setEnabled(value)
        }
    }

    Row
    {
        width: parent.width
        spacing: 8

        MenuSlider
        {
            objectName: "islandVolume"
            width: (parent.width - parent.spacing) / 2
            text: Tr.tr("common.volume")
            icon: muted ? Icon.speaker : Icon.volume
            value: ServiceAudio.pendingVolume >= 0 ? ServiceAudio.pendingVolume : ServiceAudio.volume
            muted: ServiceAudio.muted
            available: ServiceAudio.hasSink
            onMoved: value => ServiceAudio.setVolume(value)
            onIconClicked: ServiceAudio.toggleMute()
        }
        MenuSlider
        {
            objectName: "islandMicrophone"
            width: (parent.width - parent.spacing) / 2
            text: Tr.tr("common.microphone")
            icon: muted ? Icon.microphoneOff : Icon.microphone
            value: ServiceAudio.pendingMicVolume >= 0 ? ServiceAudio.pendingMicVolume : ServiceAudio.micVolume
            muted: ServiceAudio.micMuted
            available: ServiceAudio.hasSource
            onMoved: value => ServiceAudio.setMicVolume(value)
            onIconClicked: ServiceAudio.toggleMicMute()
        }
    }

    MenuSlider
    {
        objectName: "islandBrightness"
        width: parent.width
        visible: ServiceDisplay.brightnessAvailable
        iconAction: false
        text: Tr.tr("settings.island.brightness")
        icon: Icon.brightness
        value: ServiceDisplay.brightnessPending >= 0 ? ServiceDisplay.brightnessPending / 100
             : ServiceDisplay.brightnessRunning >= 0 ? ServiceDisplay.brightnessRunning / 100 : ServiceDisplay.brightness
        onMoved: value => ServiceDisplay.setBrightness(value)
    }

    Loader
    {
        width: controlCenter.width
        active: ServiceMedia.playing
        visible: active
        source: Qt.resolvedUrl("IslandMediaCard.qml")
    }

    Loader
    {
        width: controlCenter.width
        active: ServiceNotifications.count > 0
        visible: active
        source: Qt.resolvedUrl("IslandNotifications.qml")
    }
}
