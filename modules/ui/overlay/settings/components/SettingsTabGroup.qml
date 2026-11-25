pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"

Item
{
    id: group

    required property var tabs
    required property var groups
    required property int current
    property bool settled: false
    property Item surfaceHost: null
    readonly property alias surface: paint

    signal selected(int index)

    Component.onCompleted: revealTimer.restart()

    function revealTab()
    {
        const entry = tabRepeater.itemAt(current);
        if (!entry || navigation.width <= 0 || navigation.height <= 0 || entry.tabHeight <= 0) return false;
        if (current === 0)
        {
            navigationScroll.scrollTo(0, settled);
            return true;
        }
        const top = tabColumn.y + entry.y + entry.tabY;
        const bottom = top + entry.tabHeight;
        if (top < navigation.contentY || bottom > navigation.contentY + navigation.height)
            navigationScroll.scrollTo(top < navigation.contentY ? top : bottom - navigation.height, settled);
        return true;
    }
    onCurrentChanged: revealTimer.restart()
    onTabsChanged: revealTimer.restart()

    Timer
    {
        id: revealTimer
        interval: 0
        onTriggered:
        {
            if (group.revealTab()) group.settled = true;
        }
    }

    ShellSurface
    {
        id: paint
        objectName: "settingsSidebarSurface"
        parent: group.surfaceHost ?? group
        z: group.surfaceHost ? 0 : -1

        // Paint just the exposed sidebar so the compositor and scrim use the same shape.
        readonly property rect bounds: group.surfaceHost ? ShellMaterial.boundsIn(group, group.surfaceHost)
            : Qt.rect(0, 0, group.width, group.height)
        x: Math.max(0, bounds.x)
        y: Math.max(0, bounds.y)
        width: Math.max(0, Math.min(parent.width, bounds.x + bounds.width) - x)
        height: Math.max(0, Math.min(parent.height, bounds.y + bounds.height) - y)
        visible: group.visible
        radius: Math.min(Theme.settingsRadius - 8, width / 2, height / 2)
        baseColor: Theme.settingsColorSidebar
        transitionMaterial: group.surfaceHost !== null
    }

    Flickable
    {
        id: navigation
        objectName: "settingsNavigation"

        anchors { fill: parent; topMargin: 8; bottomMargin: 8 }

        clip: true
        contentWidth: width
        contentHeight: tabColumn.implicitHeight + 8
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        onWidthChanged: revealTimer.restart()
        onHeightChanged: revealTimer.restart()
        onContentHeightChanged: revealTimer.restart()

        SmoothScroll { id: navigationScroll; view: navigation }

        SelectionHighlight
        {
            id: highlight

            readonly property var entry: tabRepeater.count > 0 ? tabRepeater.itemAt(group.current) : null

            x: tabColumn.x
            y: entry ? tabColumn.y + entry.y + entry.tabY : 0
            width: tabColumn.width
            height: entry ? entry.tabHeight : Theme.settingsTabHeight
            visible: entry !== null
            color: Qt.tint(Theme.settingsColorSidebar, Theme.accentShell ? Theme.accentAlpha(0.22) : Theme.inkAlpha(0.1))
            scale: entry ? entry.tabScale : 1
            animate: group.settled
        }

        Column
        {
            id: tabColumn

            x: 8
            width: parent.width - 16
            spacing: 1

            Repeater
            {
                id: tabRepeater
                model: group.tabs

                Column
                {
                    id: entry

                    required property var modelData
                    required property int index

                    readonly property bool groupStart: index === 0 || group.tabs[index - 1].group !== modelData.group
                    readonly property real tabY: tab.y
                    readonly property real tabHeight: tab.height
                    readonly property real tabScale: tab.scale

                    width: tabColumn.width
                    spacing: 2

                    SettingsSectionHeading
                    {
                        x: 12
                        width: Math.max(0, parent.width - 24)
                        visible: entry.groupStart
                        topPadding: 6
                        bottomPadding: 4
                        title: group.groups[entry.modelData.group].toUpperCase()
                        centered: true
                    }

                    SettingsTab
                    {
                        id: tab
                        icon: entry.modelData.icon
                        title: entry.modelData.title
                        selected: group.current === entry.index
                        onClicked: group.selected(entry.index)
                    }
                }
            }
        }
    }
}
