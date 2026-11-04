pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

import "../core"

Singleton
{
    id: osd

    property bool   active: false
    property string type: ""
    property string text: ""
    property string icon: ""
    property string detail: ""
    property string context: ""
    property real   value: -1
    property bool   dim: false
    property var    currentNotification: null

    property int displayTimeout: Config.osdDuration
    property int presentationRevision: 0

    property bool armed: false
    Timer { interval: 2500; running: true; onTriggered: osd.armed = true }

    Timer { id: hideTimer; interval: osd.displayTimeout; onTriggered: osd.hide() }

    function iconOf(name) { return Icon[name] || "" }

    function allowed(type)
    {
        if (type === "notifications") return Config.notificationsEnabled;
        if (!Config.osdEnabled) return false;

        switch (type)
        {
            case "volume":
            case "audioDevice": return Config.osdTypeVolume;
            case "microphone":  return Config.osdTypeVolume;
            case "brightness":  return Config.osdTypeBrightness;
            case "wifi":        return Config.osdTypeNetwork;
            case "bluetooth":   return Config.osdTypeBluetooth;
            case "layout":      return Config.osdTypeLayout;
            case "battery":     return Config.osdTypeBattery;
        }
        return false;
    }

    property bool forced: false
    readonly property bool typeAllowed: allowed(type)
    onTypeAllowedChanged: if (active && !forced && !typeAllowed) hide()

    function hide()
    {
        hideTimer.stop();
        active = false;
        currentNotification = null;
    }

    function show(type, icon, text, value, dim, force, detail, context, timeoutOverride, notification)
    {
        if (!armed && !force && type !== "notifications") return;
        if (!(force ? Config.osdEnabled : allowed(type))) return;

        osd.forced = force === true;
        osd.currentNotification = type === "notifications" ? (notification || null) : null;
        osd.type = type;
        osd.icon = icon || "";
        osd.text = text || "";
        osd.value = value === undefined ? -1 : value;
        osd.dim = dim === true;
        osd.detail = detail || "";
        osd.context = context || "";
        osd.displayTimeout = timeoutOverride === undefined ? Config.osdDuration : Math.max(900, timeoutOverride);
        osd.presentationRevision++;
        active = true;
        hideTimer.restart();
    }

    function preview()
    {
        show("volume", iconOf("volume"), "OSD preview · 72%", 0.72, false, true);
    }

    function showNotification(n)
    {
        if (!n || !allowed("notifications")) return;

        const summary = String(n.summary || n.appName || Tr.tr("osd.notification")).replace(/<[^>]*>/g, "").trim();
        const body = String(n.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
        const app = String(n.appName || "");
        const critical = n.urgency === NotificationUrgency.Critical;

        let timeout = n.expireTimeout > 0 ? n.expireTimeout * 1000 : Config.notificationsDuration;
        if (critical && n.expireTimeout <= 0) timeout = Math.max(timeout, 10000);

        show("notifications", iconOf("bell"), summary, -1, critical, false, body, app, timeout, n);

        n.closed.connect(function()
        {
            if (osd.currentNotification === n) osd.hide();
        });
    }

    function activateNotification()
    {
        const n = osd.currentNotification;
        if (!n) return;

        const actions = n.actions || [];
        const action = actions.find(a => a.identifier === "default");
        if (action) action.invoke();
        else ServiceNotifications.dismiss(n);
        osd.hide();
    }

    function dismissNotification()
    {
        const n = osd.currentNotification;
        if (n) ServiceNotifications.dismiss(n);
        osd.hide();
    }

    Connections
    {
        target: ServiceNotifications
        function onNotificationReceived(notification) { osd.showNotification(notification) }
    }

    property double suppressVolumeUntil: 0

    function volumeEvent()
    {
        if (Date.now() < suppressVolumeUntil) return;
        show("volume", iconOf("volume"),
             ServiceAudio.muted ? Tr.tr("osd.muted") : Math.round(ServiceAudio.volume * 100) + "%",
             ServiceAudio.muted ? 0 : ServiceAudio.volume, ServiceAudio.muted);
    }

    Timer { id: volumeDebounce; interval: 60; onTriggered: osd.volumeEvent() }

    Connections
    {
        target: ServiceAudio
        function onVolumeChanged() { volumeDebounce.restart() }
        function onMutedChanged() { volumeDebounce.restart() }

        function onSinkNameChanged()
        {
            osd.suppressVolumeUntil = Date.now() + 500;
            if (osd.armed && ServiceAudio.sinkName !== "")
                osd.show("audioDevice", osd.iconOf("headphones"), Tr.tr("osd.output").arg(ServiceAudio.sinkName));
        }
    }

    function microphoneEvent()
    {
        show("microphone", iconOf(ServiceAudio.micMuted ? "microphoneOff" : "microphone"),
             ServiceAudio.micMuted ? Tr.tr("osd.microphoneMuted") : Tr.tr("osd.microphone").arg(Math.round(ServiceAudio.micVolume * 100)),
             ServiceAudio.micMuted ? 0 : ServiceAudio.micVolume, ServiceAudio.micMuted);
    }

    Timer { id: microphoneDebounce; interval: 70; onTriggered: osd.microphoneEvent() }

    Connections
    {
        target: ServiceAudio
        function onMicVolumeChanged() { microphoneDebounce.restart() }
        function onMicMutedChanged()  { microphoneDebounce.restart() }
        function onSourceNameChanged()
        {
            if (osd.armed && ServiceAudio.sourceName !== "")
                osd.show("microphone", osd.iconOf("microphone"), Tr.tr("osd.input").arg(ServiceAudio.sourceName));
        }
    }

    Connections
    {
        target: ServiceDisplay
        function onBrightnessChanged()
        {
            osd.show("brightness", osd.iconOf("brightness"),
                Math.round(ServiceDisplay.brightness * 100) + "%", ServiceDisplay.brightness);
        }
    }

    Connections
    {
        target: ServiceCompositor
        function onKeyboardLayoutIndexChanged()
        {
            if (ServiceCompositor.keyboardLayoutName !== "")
                osd.show("layout", osd.iconOf("keyboard"), ServiceCompositor.keyboardLayoutName);
        }
    }

    property int  lastBatteryPercent: -1
    property bool lastBatteryCharging: false

    function batteryEvent()
    {
        if (!ServicePower.present) { lastBatteryPercent = -1; return; }

        const percent = ServicePower.percent;
        const charging = ServicePower.charging;

        const percentChanged = percent !== lastBatteryPercent;
        const chargingChanged = charging !== lastBatteryCharging;

        lastBatteryPercent = percent;
        lastBatteryCharging = charging;

        if (!osd.armed) return;

        const isMultipleOf20 = percent % 20 === 0;
        const shouldShow = chargingChanged || (percentChanged && isMultipleOf20);

        if (!shouldShow) return;

        show("battery", iconOf("battery"),
            (charging ? Tr.tr("osd.charging") : Tr.tr("osd.battery")).arg(percent),
            ServicePower.level, false);
    }

    Connections
    {
        target: ServicePower
        function onPresentChanged()  { osd.batteryEvent() }
        function onLevelChanged()    { osd.batteryEvent() }
        function onChargingChanged() { osd.batteryEvent() }
    }

    property bool lastWiFi: false
    property bool lastEthernet: false

    function networkEvent()
    {
        if (ServiceNetwork.connectedWiFi)
        {
            if (ServiceNetwork.ssid !== "")
                show("wifi", iconOf("network"), Tr.tr("osd.connected").arg(ServiceNetwork.ssid));
            else if (!lastWiFi)
                show("wifi", iconOf("network"), Tr.tr("osd.connectedWiFi"));
        }
        else if (lastWiFi)
            show("wifi", iconOf("network"), Tr.tr("osd.disconnectedWiFi"));

        if (ServiceNetwork.connectedEthernet !== lastEthernet)
            show("wifi", iconOf("network"), ServiceNetwork.connectedEthernet ? Tr.tr("osd.connectedEthernet") : Tr.tr("osd.disconnectedEthernet"));

        lastWiFi     = ServiceNetwork.connectedWiFi;
        lastEthernet = ServiceNetwork.connectedEthernet;
    }

    Timer { id: networkDebounce; interval: 400; onTriggered: osd.networkEvent() }

    Connections
    {
        target: ServiceNetwork
        function onConnectedEthernetChanged() { networkDebounce.restart() }
        function onConnectedWiFiChanged()     { networkDebounce.restart() }
        function onSsidChanged()              { networkDebounce.restart() }
    }

    property var  btKnown: ({})
    property bool lastBtEnabled: false

    function bluetoothEvent()
    {
        if (ServiceBluetooth.enabled !== lastBtEnabled)
        {
            lastBtEnabled = ServiceBluetooth.enabled;
            if (armed) show("bluetooth", iconOf("bluetooth"), ServiceBluetooth.enabled ? Tr.tr("osd.bluetoothOn") : Tr.tr("osd.bluetoothOff"));
            if (!ServiceBluetooth.enabled) { btKnown = {}; return }
        }

        const now = {};
        const list = ServiceBluetooth.connectedDevices;
        for (let i = 0; i < list.length; i++) now[list[i].address] = list[i];

        for (const addr in now)
        {
            if (btKnown[addr] !== undefined) continue;
            const d = now[addr];
            show("bluetooth", iconOf("bluetooth"),
                 Tr.tr("osd.connected").arg(d.name) + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : ""));
        }

        for (const addr in btKnown)
            if (now[addr] === undefined) show("bluetooth", iconOf("bluetooth"), Tr.tr("osd.disconnected").arg(btKnown[addr]));

        const names = {};
        for (const addr in now) names[addr] = now[addr].name;
        btKnown = names;
    }

    Timer { id: btDebounce; interval: 300; onTriggered: osd.bluetoothEvent() }

    Connections
    {
        target: ServiceBluetooth
        function onConnectedDevicesChanged() { btDebounce.restart() }
        function onEnabledChanged() { btDebounce.restart() }
    }

    Component.onCompleted:
    {
        lastWiFi = ServiceNetwork.connectedWiFi;
        lastEthernet = ServiceNetwork.connectedEthernet;
        lastBtEnabled = ServiceBluetooth.enabled;
        lastBatteryPercent = ServicePower.present ? ServicePower.percent : -1;
        lastBatteryCharging = ServicePower.charging;
    }
}
