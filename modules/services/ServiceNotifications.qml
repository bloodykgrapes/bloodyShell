pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

import "../core"

Singleton
{
    id: serviceNotifications

    property bool dnd: false
    property double dndUntil: 0
    property int dndMinutes: 0
    property bool restoringDnd: false
    readonly property var dndOptions: [
        {label: Tr.tr("service.notifications.minutes").arg(30), value: 30},
        {label: Tr.tr("service.notifications.hours").arg(1), value: 60},
        {label: Tr.tr("service.notifications.hours").arg(2), value: 120},
        {label: Tr.tr("service.notifications.dndIndefinite"), value: 0}
    ]
    readonly property string dndStatus: !dnd ? Tr.tr("common.off") : dndUntil > 0
        ? Tr.tr("service.notifications.dndUntil").arg(Qt.formatTime(new Date(dndUntil), "hh:mm"))
        : Tr.tr("service.notifications.dndIndefinite")

    function persistDnd()
    {
        if (!Config.initialized || restoringDnd) return;
        Config.set("notificationsDnd", Config.notificationsRememberDnd && dnd);
        Config.set("notificationsDndUntil", Config.notificationsRememberDnd && dnd ? dndUntil : 0);
    }

    function restoreDnd()
    {
        if (!Config.initialized) return;
        restoringDnd = true;
        const until = Config.notificationsDndUntil;
        dnd = Config.notificationsRememberDnd && Config.notificationsDnd && (until <= 0 || until > Date.now());
        dndUntil = dnd ? until : 0;
        dndMinutes = dnd && until > 0 ? -1 : 0;
        restoringDnd = false;
        persistDnd();
    }

    function setDnd(enabled, minutes = 0)
    {
        if (!Number.isFinite(minutes) || minutes < 0) return;
        const deadline = enabled && minutes > 0 ? Date.now() + minutes * 60000 : 0;
        if (!Number.isFinite(deadline) || deadline > 8640000000000000) return;
        restoringDnd = true;
        dndUntil = deadline;
        dndMinutes = enabled ? minutes : 0;
        dnd = enabled;
        restoringDnd = false;
        persistDnd();
    }

    function expireDnd(now = Date.now())
    {
        if (dnd && dndUntil > 0 && now >= dndUntil) setDnd(false);
    }

    onDndChanged:
    {
        if (!dnd) { dndUntil = 0; dndMinutes = 0; }
        persistDnd();
    }
    onDndUntilChanged: persistDnd()
    Component.onCompleted: restoreDnd()

    Timer
    {
        interval: 1000
        repeat: true
        running: serviceNotifications.dnd && serviceNotifications.dndUntil > 0
        onTriggered: serviceNotifications.expireDnd()
    }

    Connections
    {
        target: Config
        function onInitializedChanged() { serviceNotifications.restoreDnd() }
        function onNotificationsRememberDndChanged()
        {
            serviceNotifications.persistDnd();
        }
    }

    property var receivedAt: ({})
    property int unreadCounter: 0

    signal notificationReceived(var notification)

    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property int count: history.length
    readonly property int unread: Math.min(unreadCounter, count)

    onHistoryChanged: pruneReceivedAt()

    function pruneReceivedAt()
    {
        const live = new Set(history.map(notification => String(notification.id)));
        const keys = Object.keys(receivedAt);
        if (keys.every(key => live.has(key))) return;
        const next = {};
        for (const key of keys) if (live.has(key)) next[key] = receivedAt[key];
        receivedAt = next;
    }

    readonly property var groups:
    {
        const result = [], byKey = new Map();
        for (const n of history)
        {
            const key = appKey(n);
            if (!byKey.has(key))
            {
                const group = { key: key, name: n.appName || key, items: [] };
                byKey.set(key, group);
                result.push(group);
            }
            byKey.get(key).items.push(n);
        }
        return result;
    }
    function appKey(n) { return String(n.desktopEntry || n.appName || "notifications").toLowerCase().replace(/\.desktop$/, "") }

    function desktopKey(id) { return String(id || "").toLowerCase().replace(/\.desktop$/, "") }

    function enabledFor(appId)
    {
        const key = desktopKey(appId);
        return !Config.notificationsBlockedApps.some(id => desktopKey(id) === key);
    }

    function setEnabledFor(appId, enabled)
    {
        const key = desktopKey(appId);
        if (!key) return;
        const blocked = Config.notificationsBlockedApps.filter(id => desktopKey(id) !== key);
        if (!enabled) blocked.push(key);
        Config.set("notificationsBlockedApps", blocked);
        if (!enabled) for (const n of history) if (blockedNotification(n)) dismiss(n);
    }

    function blockedNotification(n)
    {
        if (Config.notificationsBlockedApps.length === 0) return false;
        if (n.desktopEntry) return !enabledFor(n.desktopEntry);
        // Without a desktop ID, match only an unambiguous, exact application name.
        const name = String(n.appName || "").toLowerCase();
        const matches = ServiceApplications.applications.filter(app => String(app.name).toLowerCase() === name);
        return matches.length === 1 && !enabledFor(matches[0].id);
    }

    function age(n, now)
    {
        const t = n ? receivedAt[n.id] : undefined;
        if (!t) return "";
        const minutes = Math.floor((now - t) / 60000);
        if (minutes < 1) return Tr.tr("service.notifications.now");
        if (minutes < 60) return Tr.tr("service.notifications.minutes").arg(minutes);
        const date = new Date(t);
        return date.toDateString() === new Date(now).toDateString() ? Qt.formatTime(date, "hh:mm") : date.toLocaleDateString(Tr.locale, "d MMM");
    }

    NotificationServer
    {
        id: server

        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false

        onNotification: n => serviceNotifications.received(n)
    }

    function received(n)
    {
        if (blockedNotification(n)) { n.dismiss(); return; }
        n.tracked = true;

        if (n.lastGeneration) return;

        const times = Object.assign({}, receivedAt);
        times[n.id] = Date.now();
        receivedAt = times;
        unreadCounter++;

        if (!Config.notificationsEnabled) return;
        if (dnd && n.urgency !== NotificationUrgency.Critical) return;

        notificationReceived(n);
    }

    function dismiss(n)
    {
        if (n && n.tracked) n.dismiss();
    }

    function dismissGroup(key)
    {
        for (const n of history.filter(n => appKey(n) === key)) dismiss(n);
    }

    function activate(n)
    {
        if (!n) return;
        const action = (n.actions || []).find(a => a.identifier === "default");
        if (action) { action.invoke(); return; }

        const win = ServiceCompositor.windowList.find(w => w.app_id && ServiceApplications.notificationFrom(n, w.app_id));
        if (win) ServiceCompositor.focusWindow(win.id);
        dismiss(n);
    }

    function dismissAll()
    {
        const list = server.trackedNotifications.values.slice();
        for (let i = 0; i < list.length; i++) list[i].dismiss();
    }

    function markRead() { unreadCounter = 0 }
}
