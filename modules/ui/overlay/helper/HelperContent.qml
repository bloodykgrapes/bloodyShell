pragma ComponentBehavior: Bound

import QtQuick

import "../../../animations"
import "../../../common"
import "../../../core"
import "../settings/components"

Rectangle
{
    id: helperContent

    signal finished()

    property int currentPage: 0
    property int direction: 1
    property real pageReveal: 1
    readonly property var titles: [Tr.tr("helper.welcome"), Tr.tr("common.appearance"), Tr.tr("helper.components"), Tr.tr("helper.shortcuts")]
    readonly property var subtitles: [Tr.tr("helper.welcomeHint"), Tr.tr("helper.appearanceHint"), Tr.tr("helper.componentsHint"), Tr.tr("helper.shortcutsHint")]

    implicitWidth: 720
    implicitHeight: 600
    radius: Theme.settingsRadius
    color: Theme.colorSolid
    border.width: Theme.borderWidth
    border.color: Theme.colorHairline
    focus: true
    Component.onCompleted: forceActiveFocus()

    function go(index)
    {
        const next = Math.max(0, Math.min(titles.length - 1, index));
        if (next === currentPage) return;
        direction = next > currentPage ? 1 : -1;
        currentPage = next;
        content.contentY = 0;
        arrival.stop();
        pageReveal = Config.animationsEnabled ? 0 : 1;
        if (Config.animationsEnabled) arrival.start();
    }

    function advance()
    {
        if (currentPage === titles.length - 1) finished();
        else go(currentPage + 1);
    }

    NumberAnimation
    {
        id: arrival
        target: helperContent
        property: "pageReveal"
        to: 1
        duration: Theme.animationDurationControl
        easing.type: Easing.OutCubic
    }

    Keys.onReturnPressed: advance()
    Keys.onEnterPressed: advance()
    Keys.onEscapePressed: finished()
    Keys.onLeftPressed: go(currentPage - 1)
    Keys.onRightPressed: go(currentPage + 1)

    MouseArea { anchors.fill: parent; onClicked: helperContent.forceActiveFocus() }

    Column
    {
        id: heading
        x: 28
        y: 26
        width: parent.width - 100
        spacing: 8

        ShellText { label: "bloodyShell  ·  " + Tr.tr("helper.setup"); size: 11; color: Theme.text3 }
        ShellText { width: parent.width; label: helperContent.titles[helperContent.currentPage]; size: 25; font.weight: Font.DemiBold; color: Theme.text1 }
        ShellText { width: parent.width; label: helperContent.subtitles[helperContent.currentPage]; size: 12; wrapMode: Text.Wrap; color: Theme.text2 }
    }

    SettingsIconButton
    {
        anchors { top: parent.top; right: parent.right; margins: 20 }
        icon: Icon.close
        onClicked: helperContent.finished()
    }

    Flickable
    {
        id: content
        x: 28
        y: heading.y + heading.height + 24
        width: parent.width - 56
        height: Math.max(0, navigation.y - y - 20)
        contentWidth: width
        contentHeight: pages.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        opacity: helperContent.pageReveal
        transform: Translate { x: Config.animationsFluid ? (1 - helperContent.pageReveal) * 20 * helperContent.direction : 0 }

        Column
        {
            id: pages
            width: parent.width
            spacing: 12

            Column
            {
                visible: helperContent.currentPage === 0
                width: parent.width
                spacing: 12
                Tip { icon: Icon.settingsAppearance; title: Tr.tr("helper.customize"); description: Tr.tr("helper.customizeHint") }
                Tip { icon: Icon.settingsGeneral; title: Tr.tr("helper.livePreview"); description: Tr.tr("helper.livePreviewHint") }
                Tip { icon: Icon.user; title: Tr.tr("helper.reopen"); description: Tr.tr("helper.reopenHint") }
            }

            Column
            {
                visible: helperContent.currentPage === 1
                width: parent.width
                spacing: 2
                SettingsRow
                {
                    label: Tr.tr("settings.appearance.theme")
                    stacked: true
                    SettingsChoices
                    {
                        wrap: true
                        options: [{label: Tr.tr("settings.appearance.light"), value: Enums.ThemeLight}, {label: Tr.tr("settings.appearance.dark"), value: Enums.ThemeDark}]
                        current: Theme.light ? Enums.ThemeLight : Enums.ThemeDark
                        onSelected: value => Config.set("themeStyle", value)
                    }
                }
                SettingsRow
                {
                    label: Tr.tr("settings.appearance.automaticColor")
                    Toggle { checked: Config.themeAccent; onToggled: value => Config.set("themeAccent", value) }
                }
                SettingsRow
                {
                    label: Tr.tr("settings.appearance.animations")
                    stacked: true
                    SettingsChoices
                    {
                        wrap: true
                        options: [{label: Tr.tr("settings.appearance.minimal"), value: Enums.AnimationsDisabled}, {label: Tr.tr("settings.appearance.standard"), value: Enums.AnimationsStandard}, {label: Tr.tr("settings.appearance.fluid"), value: Enums.AnimationsFluid}]
                        current: Config.themeAnimations
                        onSelected: value => Config.set("themeAnimations", value)
                    }
                }
            }

            Column
            {
                visible: helperContent.currentPage === 2
                width: parent.width
                spacing: 2
                SettingsRow
                {
                    icon: Icon.settingsBar
                    label: Tr.tr("common.bar")
                    Toggle { checked: Config.barEnabled; onToggled: value => Config.set("barEnabled", value) }
                }
                SettingsRow
                {
                    icon: Icon.settingsDock
                    label: Tr.tr("common.dock")
                    Toggle { checked: Config.dockEnabled; onToggled: value => Config.set("dockEnabled", value) }
                }
                SettingsRow
                {
                    icon: Icon.settingsOSD
                    label: Tr.tr("shell.dynamicIsland")
                    Toggle { checked: Config.islandEnabled; onToggled: value => Config.set("islandEnabled", value) }
                }
            }

            Column
            {
                visible: helperContent.currentPage === 3
                width: parent.width
                spacing: 12
                Tip { icon: Icon.keyboard; title: Tr.tr("helper.launcher"); description: Tr.tr("helper.launcherHint") }
                Tip { icon: Icon.mouse; title: Tr.tr("helper.bar"); description: Tr.tr("helper.barHint") }
                Tip { icon: Icon.wallpapers; title: Tr.tr("helper.desktop"); description: Tr.tr("helper.desktopHint") }
            }
        }
    }

    Rectangle
    {
        anchors { left: parent.left; right: parent.right; bottom: navigation.top; bottomMargin: 16; leftMargin: 28; rightMargin: 28 }
        height: 1
        color: Theme.settingsColorLine
    }

    Item
    {
        id: navigation
        x: 28
        y: parent.height - height - 24
        width: parent.width - 56
        height: 34

        SettingsButton
        {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: Tr.tr("helper.back")
            icon: Icon.chevronLeft
            enabled: helperContent.currentPage > 0
            onClicked: helperContent.go(helperContent.currentPage - 1)
        }

        Row
        {
            anchors.centerIn: parent
            spacing: 6
            Repeater
            {
                model: helperContent.titles.length
                Item
                {
                    id: dot
                    required property int index
                    width: 22
                    height: 28
                    Rectangle
                    {
                        anchors.centerIn: parent
                        width: dot.index === helperContent.currentPage ? 20 : 6
                        height: 6
                        radius: 3
                        color: dot.index === helperContent.currentPage ? Theme.colorAccent : Theme.text4
                        Glide on width { duration: Theme.animationDurationControl }
                        Tint on color {}
                    }
                    MouseArea
                    {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: helperContent.go(dot.index)
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: helperContent.titles[index]
                    Accessible.onPressAction: helperContent.go(index)
                }
            }
        }

        SettingsButton
        {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: helperContent.currentPage === helperContent.titles.length - 1 ? Tr.tr("helper.finish") : Tr.tr("helper.next")
            icon: helperContent.currentPage === helperContent.titles.length - 1 ? Icon.check : Icon.chevronRight
            onClicked: helperContent.advance()
        }
    }

    component Tip: Rectangle
    {
        id: tip
        property string icon: ""
        property string title: ""
        property string description: ""
        width: parent.width
        height: Math.max(42, copy.implicitHeight) + 28
        radius: Theme.radiusLarge
        color: Theme.settingsColorCard
        ShellIcon { x: 16; anchors.verticalCenter: parent.verticalCenter; icon: tip.icon; size: 22 }
        Column
        {
            id: copy
            x: 54
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 16
            spacing: 6
            ShellText { width: parent.width; label: tip.title; size: 13; font.weight: Font.DemiBold; color: Theme.text1 }
            ShellText { width: parent.width; label: tip.description; size: 12; wrapMode: Text.Wrap; color: Theme.text2 }
        }
    }
}
