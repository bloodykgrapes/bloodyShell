pragma ComponentBehavior: Bound

import QtQuick

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"

Menu
{
    id: menuIsland
    objectName: "islandMenu"

    implicitWidth: 430
    spacing: 10

    // MenuSlot forwards its viewport budget here. The island keeps the tab row
    // fixed and gives the remaining height to the page body.
    property real maximumWidth: 100000
    property real maximumHeight: 100000
    readonly property bool ownsScrolling: true
    readonly property real pageSpacing: 10
    readonly property real tabHeight: Theme.controlHeight
    readonly property real pageMaximumHeight: Math.max(0,
        menuIsland.maximumHeight - Theme.menuPadding * 2 - menuIsland.tabHeight - menuIsland.pageSpacing)

    readonly property var currentTab: tabs.find(tab => tab.value === MenuState.islandTab) ?? tabs[0]
    readonly property string current: currentTab.value
    readonly property var tabs: [
        { value: "controls", title: Tr.tr("settings.island.controlCenter"), icon: Icon.widgets,
            source: Qt.resolvedUrl("pages/IslandControlCenter.qml") },
        { value: "calendar", title: Tr.tr("settings.island.calendar"), icon: Icon.calendar,
            source: Qt.resolvedUrl("MenuClock.qml") },
        { value: "weather", title: Tr.tr("settings.island.weather"), icon: Icon.weather,
            emptyText: Tr.tr("settings.island.weatherEmpty") },
        { value: "system", title: Tr.tr("settings.island.systemMonitor"), icon: Icon.processor,
            emptyText: Tr.tr("settings.island.systemMonitorEmpty") },
        { value: "shelf", title: Tr.tr("settings.island.shelf"), icon: Icon.fileAssociations,
            emptyText: Tr.tr("settings.island.shelfEmpty") }
    ]

    function selectTab(value)
    {
        MenuState.islandTab = value;
        if (value === "controls") ServiceNotifications.markRead();
    }

    function syncEmptyPage()
    {
        const page = pageLoader.item;
        if (!page || currentTab.source) return;
        page.pageTitle = currentTab.title;
        page.pageIcon = currentTab.icon;
        page.pageText = currentTab.emptyText;
    }

    onCurrentTabChanged: Qt.callLater(syncEmptyPage)

    Column
    {
        id: islandBody
        width: parent.width
        spacing: menuIsland.pageSpacing

        Row
        {
            id: tabRow
            width: parent.width
            spacing: 4

            Repeater
            {
                model: menuIsland.tabs

                Button
                {
                    id: tab
                    required property var modelData

                    readonly property bool selected: modelData.value === menuIsland.current
                    readonly property int collapsedWidth: Math.min(54, Math.max(0,
                        Math.floor((tabRow.width - tabRow.spacing * (menuIsland.tabs.length - 1)) / (menuIsland.tabs.length + 1.5))))
                    readonly property int selectedWidth: Math.max(collapsedWidth,
                        tabRow.width - (menuIsland.tabs.length - 1) * (collapsedWidth + tabRow.spacing))

                    width: selected ? selectedWidth : collapsedWidth
                    height: menuIsland.tabHeight
                    radius: height / 2
                    icon: modelData.icon
                    iconSize: 16
                    text: selected ? modelData.title : ""
                    textSize: 11
                    color: selected ? Theme.menuControlSelected : "transparent"
                    textColor: selected ? Theme.text1 : Theme.text2
                    hoverScale: 1
                    pressScale: 0.96
                    Accessible.name: modelData.title
                    onClicked: menuIsland.selectTab(modelData.value)
                    Glide on width { duration: Theme.animationDurationControl }

                    Rectangle
                    {
                        visible: tab.modelData.value === "controls" && ServiceNotifications.unread > 0 && !tab.selected
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 5
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.colorAccent
                    }
                }
            }
        }

        Flickable
        {
            id: pageScroll
            objectName: "islandPageScroll"
            width: parent.width
            height: Math.min(menuIsland.pageMaximumHeight, pageLoader.height)
            implicitHeight: height
            contentWidth: width
            contentHeight: pageLoader.height
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            clip: interactive

            SmoothScroll { view: pageScroll }

            Loader
            {
                id: pageLoader
                width: pageScroll.width
                height: item ? item.implicitHeight : 0
                source: menuIsland.currentTab.source ?? Qt.resolvedUrl("pages/IslandEmptyPage.qml")
                onLoaded:
                {
                    pageScroll.contentY = 0;
                    menuIsland.syncEmptyPage();
                }
            }
        }
    }
}
