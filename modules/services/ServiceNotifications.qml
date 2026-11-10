pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

import "../core"

Singleton
{
    id: serviceNotifications

    property bool dnd: false

    function restoreDnd()
    {
        if (Config.initialized) dnd = Config.notificationsRememberDnd && Config.notificationsDnd;
    }

    onDndChanged: if (Config.initialized && Config.notificationsRememberDnd) Config.set("notificationsDnd", dnd)
    Component.onCompleted: restoreDnd()

    Connections
    {
        target: Config
        function onInitializedChanged() { serviceNotifications.restoreDnd() }
        function onNotificationsRememberDndChanged()
        {
            if (Config.initialized) Config.set("notificationsDnd", Config.notificationsRememberDnd && serviceNotifications.dnd);
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
