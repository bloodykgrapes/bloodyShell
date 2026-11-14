pragma ComponentBehavior: Bound

import QtQuick

import "../../../common"
import "../../../core"
import "../../../services"
import "../components"

Sidebar
{
    id: rightSidebar
    side: "right"
    property string currentTab: "controls"

    onCurrentTabChanged:
    {
        scrollView.cancelFlick();
        scrollView.contentY = 0;
    }

    header: TabRow
    {
        objectName: "rightSidebarTabs"
        options: [
            {label: Tr.tr("sidebar.controls"), value: "controls"},
            {label: Tr.tr("common.notifications"), value: "notifications", badge: ServiceNotifications.unread}
        ]
        current: rightSidebar.currentTab
        onSelected: value => rightSidebar.currentTab = value
    }

    Loader
    {
        width: parent.width
        height: item ? item.implicitHeight : 0
        active: rightSidebar.visible
        sourceComponent: rightSidebar.currentTab === "notifications" ? notifications : controls
    }

    Component
    {
        id: controls
        ControlCenter { host: rightSidebar; active: rightSidebar.opened }
    }
    Component
    {
        id: notifications
        Notifications { active: rightSidebar.opened }
    }
}
