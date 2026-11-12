pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

import "../core"

Singleton
{
    id: island

    property var queue: []
    property var notice: null
    property var mediaMenuOwner: null
    property string valueOutput: ""
    readonly property bool active: !ServiceLock.locked && (ServiceOSD.active || notice !== null || ServiceMedia.playing)

    function plain(text) { return String(text || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() }
    function matches(name, output) { return output === "" || name === output }
    function mediaView()
    {
        return { kind: "media", title: ServiceMedia.title, subtitle: ServiceMedia.artist,
            art: ServiceMedia.art, value: -1, icon: Icon.music };
    }
    function setMediaMenu(client, open)
    {
        if (open) mediaMenuOwner = client;
        else if (mediaMenuOwner === client) mediaMenuOwner = null;
    }
    function view(output)
    {
        if (ServiceLock.locked) return { kind: "" };
        if (ServiceOSD.active && matches(output, valueOutput))
            return { kind: "osd", title: ServiceOSD.text, subtitle: ServiceOSD.detail || ServiceOSD.context,
                icon: ServiceOSD.icon, value: ServiceOSD.value, dim: ServiceOSD.dim };
        if (notice && matches(output, notice.output))
            return { kind: "notification", title: notice.title, subtitle: notice.body || notice.app,
                notification: notice.notification, value: -1, icon: Icon.bell };
        if (ServiceMedia.playing && !ServiceCompositor.fullscreenOnOutput(output))
            return mediaView();
        return { kind: "" };
    }

    function receive(notification)
    {
        if (!notification || !Config.notificationsEnabled || ServiceLock.locked) return;
        const critical = notification.urgency === NotificationUrgency.Critical;
        if (ServiceNotifications.dnd && !critical) return;
        const item = { notification: notification, title: plain(notification.summary || notification.appName),
            body: plain(notification.body), app: plain(notification.appName), critical: critical,
            output: ServiceCompositor.focusedOutput,
            duration: notification.expireTimeout > 0 ? notification.expireTimeout * 1000
                : Math.max(critical ? 10000 : 900, Config.notificationsDuration) };
        if (notice && notice.notification === notification) { notice = item; timeout.restart(); return; }
        queue = queue.filter(entry => entry.notification !== notification).slice(-7).concat([item]);
        notification.closed.connect(() => island.remove(notification));
        advance();
    }
    function advance()
    {
        if (notice || queue.length === 0) return;
        notice = queue[0];
        queue = queue.slice(1);
    }
    function remove(notification)
    {
        queue = queue.filter(entry => entry.notification !== notification);
        if (notice && notice.notification === notification)
        {
            timeout.stop();
            notice = null;
            advance();
        }
    }
    function dismiss()
    {
        if (!notice) return;
        const notification = notice.notification;
        remove(notification);
        ServiceNotifications.dismiss(notification);
    }
    function activate()
    {
        if (!notice) return;
        const notification = notice.notification;
        ServiceNotifications.activate(notification);
        remove(notification);
    }
    function clear()
    {
        timeout.stop();
        queue = [];
        notice = null;
    }

    Timer
    {
        id: timeout
        interval: island.notice ? island.notice.duration : Config.notificationsDuration
        running: island.notice !== null && !ServiceOSD.active && !ServiceLock.locked
            && !(island.mediaMenuOwner && island.matches(island.mediaMenuOwner.output, island.notice.output))
        onTriggered:
        {
            island.notice = null;
            island.advance();
        }
    }
    Connections
    {
        target: ServiceOSD
        function onPresentationRevisionChanged() { island.valueOutput = ServiceCompositor.focusedOutput }
    }
    Connections
    {
        target: ServiceNotifications
        function onNotificationReceived(notification) { island.receive(notification) }
        function onDndChanged()
        {
            if (!ServiceNotifications.dnd) return;
            island.queue = island.queue.filter(entry => entry.critical);
            if (island.notice && !island.notice.critical) { island.notice = null; island.advance(); }
        }
    }
    Connections
    {
        target: Config
        function onNotificationsEnabledChanged() { if (!Config.notificationsEnabled) island.clear() }
    }
    Connections
    {
        target: ServiceLock
        function onLockedChanged()
        {
            if (!ServiceLock.locked) return;
            island.clear();
            ServiceOSD.hide();
        }
    }
}
