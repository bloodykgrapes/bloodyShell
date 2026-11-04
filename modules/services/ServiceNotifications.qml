pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

import "../core"

Singleton
{
    id: serviceNotifications

    property bool dnd: false

    property var receivedAt: ({})
    property int unreadCounter: 0

    signal notificationReceived(var notification)

    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property int count: history.length
    readonly property int unread: Math.min(unreadCounter, count)

    readonly property var groups:
    {
        const order = [], byKey = {};
        for (const n of history)
        {
            const key = appKey(n);
            if (!byKey[key])
            {
                byKey[key] = { key: key, name: n.appName || key, items: [] };
                order.push(key);
            }
            byKey[key].items.push(n);
        }
        return order.map(k => byKey[k]);
    }
    function appKey(n) { return String(n.desktopEntry || n.appName || "notifications").toLowerCase().replace(/\.desktop$/, "") }

    function age(n, now)
    {
        const t = n ? receivedAt[n.id] : undefined;
        if (!t) return "";
        const minutes = Math.floor((now - t) / 60000);
        if (minutes < 1) return Tr.tr("service.notifications.now");
        if (minutes < 60) return Tr.tr("service.notifications.min").arg(minutes);
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
