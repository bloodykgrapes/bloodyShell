pragma Singleton

import QtQuick
import Quickshell

import "../services"

Singleton
{
    readonly property string path: Theme.light ?
        Qt.resolvedUrl("../../assets/icons/dark/") :
        Qt.resolvedUrl("../../assets/icons/light/")

    readonly property string battery:
        ServicePower.charging      ? path + "battery_charging.svg" :
        ServicePower.level >= 0.85 ? path + "battery_full.svg" :
        ServicePower.level >= 0.70 ? path + "battery_6.svg" :
        ServicePower.level >= 0.55 ? path + "battery_5.svg" :
        ServicePower.level >= 0.40 ? path + "battery_4.svg" :
        ServicePower.level >= 0.25 ? path + "battery_3.svg" :
        ServicePower.level >= 0.10 ? path + "battery_2.svg" : path + "battery_1.svg"

    readonly property string bluetooth:
        ServiceBluetooth.connected ? path + "bluetooth_connected.svg" :
        ServiceBluetooth.enabled   ? bluetoothON : bluetoothOFF

    readonly property string network:
        ServiceNetwork.connectedEthernet ? networkEthernet :
        ServiceNetwork.connectedWiFi     ? wifiLevel(ServiceNetwork.strengthPercent(ServiceNetwork.signal)) : networkOffline

    readonly property string volume:
        ServiceAudio.muted ||
        ServiceAudio.volume === 0  ? path + "volume_muted.svg" :
        ServiceAudio.volume < 0.33 ? path + "volume_1.svg" :
        ServiceAudio.volume < 0.66 ? path + "volume_2.svg" : path + "volume_3.svg"

    readonly property string notifications: ServiceNotifications.dnd ? bellOFF : bellON

    readonly property string user: path + "user.svg"
    readonly property string tray: path + "tray.svg"
    readonly property string keyboard: path + "keyboard.svg"

    readonly property string bluetoothON:        path + "bluetooth_enabled.svg"
    readonly property string bluetoothOFF:       path + "bluetooth_disabled.svg"

    readonly property string networkWiFiON:   path + "wifi.svg"
    readonly property string networkWiFiOFF:  path + "wifi_off.svg"
    readonly property string networkEthernet: path + "ethernet.svg"
    readonly property string networkOffline:  path + "offline.svg"

    readonly property string bell: bellON
    readonly property string speaker:       path + "volume_3.svg"
    readonly property string microphone:    path + "microphone.svg"
    readonly property string microphoneOff: path + "microphone_off.svg"
    readonly property string music:         path + "music.svg"
    readonly property string mediaPlay:     path + "media_play.svg"
    readonly property string mediaPause:    path + "media_pause.svg"
    readonly property string mediaNext:     path + "media_next.svg"
    readonly property string mediaPrevious: path + "media_previous.svg"
    readonly property string mediaShuffle:  path + "media_shuffle.svg"
    readonly property string mediaRepeat:   path + "media_repeat.svg"
    readonly property string headphones:    path + "headphones.svg"
    readonly property string mouse:         path + "mouse.svg"
    readonly property string phone:         path + "phone.svg"
    readonly property string gamepad:       path + "gamepad.svg"
    readonly property string linkOff:       path + "link_off.svg"
    readonly property string eye:           path + "visibility.svg"
    readonly property string eyeOff:        path + "visibility_off.svg"

    function bluetoothDevice(kind)
    {
        const k = String(kind || "");
        if (/headset|headphone/.test(k)) return headphones;
        if (/audio|speaker|card/.test(k)) return speaker;
        if (/mouse/.test(k)) return mouse;
        if (/keyboard/.test(k)) return keyboard;
        if (/gaming|joystick/.test(k)) return gamepad;
        if (/phone/.test(k)) return phone;
        if (/computer|tablet/.test(k)) return path + "display.svg";
        return bluetoothON;
    }
    readonly property string brightness: path + "brightness.svg"

    readonly property string chevronUp:    path + "chevron_up.svg"
    readonly property string chevronDown:  path + "chevron_down.svg"
    readonly property string chevronLeft:  path + "chevron_left.svg"
    readonly property string chevronRight: path + "chevron_right.svg"
    readonly property string add:   path + "add.svg"
    readonly property string pin:   path + "pin.svg"
    readonly property string unpin: path + "unpin.svg"
    readonly property string minus: path + "minus.svg"
    readonly property string check: path + "check.svg"

    function wifiLevel(strength)
    {
        if (strength >= 67) return networkWiFiON;
        if (strength >= 34) return path + "wifi_2.svg";
        return path + "wifi_1.svg";
    }

    readonly property string bellON:  path + "notifications.svg"
    readonly property string bellOFF: path + "notifications_disabled.svg"

    readonly property string settings: path + "settings.svg"
    readonly property string reload:   path + "reload.svg"
    readonly property string update:   path + "update.svg"
    readonly property string search:   path + "search.svg"
    readonly property string wallpapers: path + "wallpapers.svg"

    readonly property string trash: path + "trash.svg"
    readonly property string close: path + "close.svg"

    readonly property string userLock:   path + "lock.svg"
    readonly property string userLogOut: path + "logout.svg"

    readonly property string computerSleep:    path + "sleep.svg"
    readonly property string computerReboot:   path + "reboot.svg"
    readonly property string computerPowerOff: path + "poweroff.svg"

    readonly property string settingsGeneral: path + "settings.svg"
    readonly property string settingsUpdates: path + "update.svg"

    readonly property string profileSaver:       path + "profile_saver.svg"
    readonly property string profileBalanced:    path + "profile_balanced.svg"
    readonly property string profilePerformance: path + "profile_performance.svg"

    readonly property string settingsDisplay:      path + "display.svg"
    readonly property string settingsSound:        path + "volume_3.svg"
    readonly property string settingsPower:        path + "power_profile.svg"
    readonly property string settingsStorage:      path + "storage.svg"
    readonly property string settingsDevices:      path + "devices.svg"
    readonly property string settingsApplications: path + "apps.svg"
    readonly property string settingsTimeLanguage: path + "language.svg"

    readonly property string settingsAppearance:   path + "palette.svg"
    readonly property string settingsDesktop:      path + "desktop.svg"
    readonly property string settingsBar:          path + "bar.svg"
    readonly property string settingsDock:         path + "dock.svg"
    readonly property string settingsOSD:          path + "osd.svg"

    readonly property string settingsAbout:        path + "info.svg"
}
