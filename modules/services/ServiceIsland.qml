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
    property var notificationWatchers: []
    readonly property string primaryOutput: primaryOutputFor(Quickshell.screens, Config.barScreens)
    readonly property bool recordingActive: Config.islandRecordingIndicator && ServiceRecording.active
    readonly property bool mediaActive: Config.islandMedia && ServiceMedia.playing
    readonly property bool active: !ServiceLock.locked && (ServiceOSD.active || notice !== null || recordingActive || mediaActive)

    function plain(text) { return String(text || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() }
    function primaryOutputFor(screens, preferred)
    {
        for (const name of preferred)
            if (screens.some(screen => screen.name === name)) return name;
        return screens.length > 0 ? screens[0].name : "";
    }
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
        if (ServiceLock.locked || output !== primaryOutput) return { kind: "" };
        if (ServiceOSD.active)
            return { kind: "osd", title: ServiceOSD.text, subtitle: ServiceOSD.detail || ServiceOSD.context,
                icon: ServiceOSD.icon, value: ServiceOSD.value, dim: ServiceOSD.dim };
        if (notice)
            return { kind: "notification", title: notice.title, subtitle: notice.body || notice.app,
                notification: notice.notification, value: -1, icon: Icon.bell };
        if (recordingActive)
            return {kind: "recording", title: Tr.tr("recording.active"), subtitle: ServiceRecording.detail, icon: Icon.recording, value: -1};
        if (mediaActive && !ServiceCompositor.fullscreenOnOutput(output))
            return mediaView();
        return { kind: "" };
    }

    function receive(notification)
    {
        if (!notification || !Config.notificationsEnabled || ServiceLock.locked) return;
        const critical = notification.urgency === NotificationUrgency.Critical;
        if (ServiceNotifications.dnd && !critical) return;
        const watcher = watch(notification);
        const item = { notification: notification, watcher: watcher, title: plain(notification.summary || notification.appName),
            body: plain(notification.body), app: plain(notification.appName), critical: critical,
            duration: notification.expireTimeout > 0 ? notification.expireTimeout * 1000
                : Math.max(critical ? 10000 : 900, Config.notificationsDuration) };
        if (notice && notice.notification === notification) { notice = item; timeout.restart(); return; }
        queue = queue.filter(entry => entry.notification !== notification).slice(-7).concat([item]);
        advance();
    }
    function watch(notification)
    {
        const existing = notificationWatchers.find(watcher => watcher.notification === notification);
        if (existing) return existing;
        const watcher = notificationWatcher.createObject(island, { notification: notification });
        notificationWatchers = notificationWatchers.concat([watcher]);
        return watcher;
    }
    function unwatch(watcher)
    {
        removeItems(item => item.watcher === watcher);
        notificationWatchers = notificationWatchers.filter(item => item !== watcher);
        watcher.destroy();
    }
    Component
    {
        id: notificationWatcher

        // Native references clear on destruction without retaining stale JavaScript weak keys.
        QtObject
        {
            id: watcher
            property QtObject notification
            onNotificationChanged: if (!notification) island.unwatch(watcher)
            Component.onCompleted: lifecycle.target = notification
            property Connections lifecycle: Connections
            {
                target: null
                function onClosed() { island.remove(watcher.notification) }
            }
        }
    }
    function advance()
    {
        if (notice || queue.length === 0) return;
        notice = queue[0];
        queue = queue.slice(1);
    }
    function remove(notification)
    {
        removeItems(item => item.notification === notification);
    }
    function removeItems(matches)
    {
        queue = queue.filter(entry => !matches(entry));
        if (notice && matches(notice))
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
            && !(island.mediaMenuOwner && island.mediaMenuOwner.output === island.primaryOutput)
        onTriggered:
        {
            island.notice = null;
            island.advance();
        }
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
