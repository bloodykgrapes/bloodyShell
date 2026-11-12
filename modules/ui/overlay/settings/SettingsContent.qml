pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell.Widgets

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"
import "components"

Rectangle
{
    id: settingsContent

    readonly property var tabs: Registry.settings
    readonly property int current: Math.max(0, Math.min(tabs.length - 1, OverlayState.settingsPage))

    function select(index) { OverlayState.settingsPage = Math.max(0, Math.min(tabs.length - 1, index)) }

    function revealTab()
    {
        const entry = tabRepeater.itemAt(current);
        if (!entry) return;
        const top = tabColumn.y + entry.y + entry.tabY;
        const bottom = top + entry.tabHeight;
        if (top >= navigation.contentY && bottom <= navigation.contentY + navigation.height) return;
        navigationScroll.scrollTo(top < navigation.contentY ? top : bottom - navigation.height, settled);
    }
    onCurrentChanged: revealTimer.restart()
    onTabsChanged: revealTimer.restart()

    Timer
    {
        id: revealTimer
        interval: 0
        onTriggered:
        {
            settingsContent.revealTab();
            settingsContent.settled = true;
        }
    }

    radius: Theme.settingsRadius
    color: Theme.settingsColorBackground
    clip: true

    focus: true
    Component.onCompleted:
    {
        forceActiveFocus();
        revealTimer.restart();
    }

    property bool settled: false

    Keys.onPressed: event =>
    {
        if (event.key === Qt.Key_Escape)          OverlayState.hide("settings");
        else if (!settingsContent.activeFocus)               return;
        else if (event.key === Qt.Key_Up)         select(current - 1);
        else if (event.key === Qt.Key_Down)       select(current + 1);
        else if (event.key === Qt.Key_Home)       select(0);
        else if (event.key === Qt.Key_End)        select(tabs.length - 1);
        else return;
        event.accepted = true;
    }

    MouseArea { anchors.fill: parent; onClicked: settingsContent.forceActiveFocus() }

    Rectangle
    {
        id: sidebar

        x: 1
        y: 1
        width: Math.min(settingsContent.width < 900 ? Theme.settingsSidebar - 24 : Theme.settingsSidebar, Math.max(180, settingsContent.width * 0.32))
        height: parent.height - 2

        topLeftRadius: settingsContent.radius - 1
        bottomLeftRadius: settingsContent.radius - 1
        color: Theme.settingsColorSidebar

        Row
        {
            id: brand

            x: 20
            y: 24
            width: parent.width - 40
            spacing: 12

            ClippingRectangle
            {
                width: 38
                height: 38
                radius: 10
                color: "transparent"

                Image
                {
                    anchors.fill: parent
                    source: Qt.resolvedUrl("../../../../assets/icons/logo.png")
                    sourceSize: Qt.size(76, 76)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Column
            {
                width: Math.max(0, brand.width - 38 - brand.spacing)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                ShellText { width: parent.width; label: "bloodyShell"; size: 15; color: Theme.text1; font.bold: true }
                ShellText { width: parent.width; label: Tr.tr("common.settings"); size: 11; color: Theme.text3 }
            }
        }

        Flickable
        {
            id: navigation

            y: brand.y + brand.height + 18
            width: parent.width
            height: parent.height - y - footer.height - 12

            clip: true
            contentHeight: tabColumn.implicitHeight + 8
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            SmoothScroll { id: navigationScroll; view: navigation }

            Controls.ScrollBar.vertical: Controls.ScrollBar
            {
                width: 4
                anchors.right: parent.right
                anchors.rightMargin: 3
                padding: 1
                policy: Controls.ScrollBar.AsNeeded
                active: navigation.moving || hovered || pressed
                contentItem: Rectangle { implicitWidth: 2; radius: 1; color: Theme.text4; opacity: 0.4 }
            }

            Rectangle
            {
                id: highlight

                readonly property var entry: tabRepeater.count > 0 ? tabRepeater.itemAt(settingsContent.current) : null

                x: tabColumn.x
                y: entry ? tabColumn.y + entry.y + entry.tabY : 0
                width: tabColumn.width
                height: entry ? entry.tabHeight : Theme.settingsTabHeight
                radius: Theme.radiusLarge - 2
                color: Theme.colorSelection
                visible: entry !== null
                scale: entry ? entry.tabScale : 1

                Glide on y { enabled: Config.animationsEnabled && settingsContent.settled }
            }

            Column
            {
                id: tabColumn

                x: 12
                width: parent.width - 24
                spacing: 2

                Repeater
                {
                    id: tabRepeater
                    model: settingsContent.tabs

                    Column
                    {
                        id: entry

                        required property var modelData
                        required property int index

                        readonly property bool groupStart: index === 0 || settingsContent.tabs[index - 1].group !== modelData.group
                        readonly property real tabY: tab.y
                        readonly property real tabHeight: tab.height
                        readonly property real tabScale: tab.scale

                        width: tabColumn.width
                        spacing: 2

                        ShellText
                        {
                            x: 12
                            visible: entry.groupStart && entry.modelData.group !== 0
                            topPadding: 10
                            bottomPadding: 4
                            label: Registry.settingsGroups[entry.modelData.group].toUpperCase()
                            size: 10
                            color: Theme.text4
                            font.bold: true
                            font.letterSpacing: 1.2
                        }

                        SettingsTab
                        {
                            id: tab
                            icon: entry.modelData.icon
                            title: entry.modelData.title
                            selected: settingsContent.current === entry.index
                            onClicked:
                            {
                                settingsContent.select(entry.index);
                                settingsContent.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

        Item
        {
            id: footer

            anchors.bottom: parent.bottom
            width: parent.width
            height: 44

            Rectangle
            {
                x: 16
                width: parent.width - 32
                height: 1
                color: Theme.settingsColorLine
            }

            ShellText
            {
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                label: Tr.tr("settings.version").arg(ServiceUpdate.version)
                size: 11
                color: Theme.text4
            }
        }
    }

    Rectangle
    {
        x: sidebar.x + sidebar.width
        y: 1
        width: 1
        height: parent.height - 2
        color: Theme.settingsColorLine
    }

    Item
    {
        id: pages

        property int  shown: -1
        property bool flip: false

        function present(index)
        {
            if (index === shown) return;

            const direction = shown < 0 ? 0 : index > shown ? 1 : -1;
            shown = index;
            flip = !flip;

            (flip ? slotB : slotA).leave(direction);
            (flip ? slotA : slotB).enter(settingsContent.tabs[index].page, direction);
        }

        x: sidebar.x + sidebar.width + 1
        y: 1
        width: parent.width - x - 1
        height: parent.height - 2
        clip: true

        Component.onCompleted: present(settingsContent.current)
        Connections { target: settingsContent; function onCurrentChanged() { pages.present(settingsContent.current) } }

        SettingsPageSlot { id: slotA; anchors.fill: parent }
        SettingsPageSlot { id: slotB; anchors.fill: parent }
    }

    SettingsIconButton
    {
        anchors { top: parent.top; right: parent.right; margins: 16 }
        width: 32
        height: 32
        icon: Icon.close
        iconSize: 14
        text: Tr.tr("common.close")
        onClicked: OverlayState.hide("settings")
    }

    readonly property alias popupLayer: popupLayer
    Item { id: popupLayer; anchors.fill: parent; z: 1000 }
}
