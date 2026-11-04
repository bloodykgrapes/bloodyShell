import QtQuick
import Quickshell.Widgets

import "../../../components"
import "../../../components/settings"
import "../../../core"
import "../../../services"

SettingsPage
{
    id: pageAppearance

    title: Tr.tr("common.appearance")
    subtitle: Tr.tr("settings.appearance.howTheShellLooks")

    Component.onCompleted: ServiceAppearance.refresh()

    function withCurrent(list, current)
    {
        if (current === "" || list.indexOf(current) >= 0) return list.map(n => ({ label: n, value: n }));
        return [{ label: Tr.tr("settings.appearance.notInstalled").arg(current), value: current }].concat(list.map(n => ({ label: n, value: n })));
    }

    SettingsGroup
    {
        title: Tr.tr("common.shell")

        SettingsRow
        {
            label: Tr.tr("settings.appearance.theme")
            stacked: true

            Row
            {
                id: themeCards

                readonly property var themes:
                [
                    { label: Tr.tr("settings.appearance.light"), value: Enums.ThemeLight }, { label: Tr.tr("settings.appearance.graphite"), value: Enums.ThemeGraphite },
                    { label: Tr.tr("settings.appearance.darker"), value: Enums.ThemeDarker }, { label: Tr.tr("settings.appearance.black"), value: Enums.ThemeBlack }
                ]
                width: parent.width
                spacing: 10

                Repeater
                {
                    model: themeCards.themes

                    Item
                    {
                        id: themeCard

                        required property var modelData
                        readonly property bool  current: Config.themeStyle === modelData.value
                        readonly property var   colors: Theme.styles[modelData.value]
                        readonly property bool  light: modelData.value === Enums.ThemeLight
                        readonly property color ink: light ? "#1d1d1f" : "#ffffff"
                        readonly property color mark: Config.themeAccent ? Theme.accentBase : ink

                        width: (themeCards.width - themeCards.spacing * 3) / 4
                        height: preview.height + 22

                        scale: cardArea.pressed ? 0.96 : cardArea.containsMouse ? 1.03 : 1
                        Spring on scale {}

                        Rectangle
                        {
                            id: preview

                            width: parent.width
                            height: Math.round(width * 0.62)
                            radius: Theme.radiusLarge
                            color: themeCard.colors[1]
                            border.width: themeCard.current ? 2 : 1
                            border.color: themeCard.current ? Theme.text1 : Theme.colorLine
                            Tint on border.color {}

                            Rectangle
                            {
                                x: 8; y: 7
                                width: parent.width - 16
                                height: 8
                                radius: 4
                                color: themeCard.colors[0]
                                border.width: 1
                                border.color: Qt.rgba(themeCard.ink.r, themeCard.ink.g, themeCard.ink.b, 0.08)

                                Rectangle { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 3; radius: 1.5; color: themeCard.mark }
                                Rectangle
                                {
                                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                    width: 14; height: 3; radius: 1.5
                                    color: Qt.rgba(themeCard.ink.r, themeCard.ink.g, themeCard.ink.b, 0.4)
                                }
                            }

                            Rectangle
                            {
                                x: 8; y: 21
                                width: parent.width - 16
                                height: parent.height - 29
                                radius: 6
                                color: themeCard.colors[0]
                                border.width: 1
                                border.color: Qt.rgba(themeCard.ink.r, themeCard.ink.g, themeCard.ink.b, 0.08)

                                Column
                                {
                                    x: 6; y: 6
                                    spacing: 4
                                    Rectangle { width: 30; height: 3; radius: 1.5; color: Qt.rgba(themeCard.ink.r, themeCard.ink.g, themeCard.ink.b, 0.7) }
                                    Rectangle { width: 22; height: 3; radius: 1.5; color: Qt.rgba(themeCard.ink.r, themeCard.ink.g, themeCard.ink.b, 0.3) }
                                }
                                Rectangle
                                {
                                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                    width: 16; height: 9; radius: 4.5
                                    color: themeCard.mark
                                    Rectangle
                    {
                        anchors { right: parent.right; rightMargin: 1.5; verticalCenter: parent.verticalCenter }
                        width: 6; height: 6; radius: 3
                        color: themeCard.colors[0]
                    }
                                }
                            }
                        }

                        ShellText
                        {
                            anchors { horizontalCenter: parent.horizontalCenter; top: preview.bottom; topMargin: 6 }
                            label: themeCard.modelData.label
                            size: 11
                            color: themeCard.current ? Theme.text1 : Theme.text3
                            Tint on color {}
                        }

                        MouseArea
                        {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.set("themeStyle", themeCard.modelData.value)
                        }

                        Accessible.role: Accessible.RadioButton
                        Accessible.name: themeCard.modelData.label
                        Accessible.checked: themeCard.current
                    }
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.accentShell")
            description: Tr.tr("settings.appearance.colorsTheSelectionHoverHint")
            SettingsSwitch { checked: Config.themeAccent; onToggled: value => Config.set("themeAccent", value) }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.backgroundStyle")
            stacked: true

            Row
            {
                spacing: 10
                Repeater
                {
                    model: [{ label: Tr.tr("settings.appearance.solid"), value: Enums.BackgroundSolid }, { label: Tr.tr("settings.appearance.blur"), value: Enums.BackgroundBlur }, { label: Tr.tr("settings.appearance.transparent"), value: Enums.BackgroundTransparent }]
                    SettingsStyleCard
                    {
                        required property var modelData
                        kind: "background"
                        value: modelData.value
                        label: modelData.label
                        current: Config.themeBackground === modelData.value
                        onClicked: Config.set("themeBackground", modelData.value)
                    }
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.blurStyle")
            visible: Config.themeBackground === Enums.BackgroundBlur

            SettingsChoices
            {
                options: [{ label: Tr.tr("settings.appearance.liquid"), value: 25 }, { label: Tr.tr("settings.appearance.frosted"), value: 60 }, { label: Tr.tr("settings.appearance.acrylic"), value: 100 }]
                current: Config.themeBackgroundBlur
                onSelected: value => Config.set("themeBackgroundBlur", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.transparencyStrength")
            visible: Config.themeBackground === Enums.BackgroundTransparent

            SettingsChoices
            {
                options: [{ label: "25%", value: 25 }, { label: "50%", value: 50 }, { label: "75%", value: 75 }]
                current: Config.themeBackgroundTransparent
                onSelected: value => Config.set("themeBackgroundTransparent", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.border")
            SettingsSwitch { checked: Config.themeBorder; onToggled: value => Config.set("themeBorder", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.scale")
            SettingsStepper
            {
                value: Config.themeScale
                from: 0.8; to: 1.5; step: 0.05; decimals: 2; suffix: "×"
                onEdited: value => Config.set("themeScale", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.animations")
            SettingsChoices
            {
                options: [{ label: Tr.tr("settings.appearance.minimal"), value: Enums.AnimationsDisabled }, { label: Tr.tr("settings.appearance.standard"), value: Enums.AnimationsStandard }, { label: Tr.tr("settings.appearance.fluid"), value: Enums.AnimationsFluid }]
                current: Config.themeAnimations
                onSelected: value => Config.set("themeAnimations", value)
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.appearance.wallpaper")

        Item
        {
            width: parent.width
            height: 196

            ClippingRectangle
            {
                id: wallpaper

                anchors { fill: parent; margins: 12 }
                radius: Theme.radiusLarge
                color: Theme.colorField

                ShellIcon
                {
                    anchors.centerIn: parent
                    visible: wallImage.status !== Image.Ready
                    icon: Icon.wallpapers
                    size: 28
                    opacity: 0.4
                }
                Image
                {
                    id: wallImage
                    anchors.fill: parent
                    source: Config.wallpaperCurrent !== "" ? "file://" + String(Config.wallpaperCurrent).replace(/^file:\/\//, "") : ""
                    sourceSize: Qt.size(720, 360)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Smooth on opacity { duration: 300 }

                    scale: wallArea.containsMouse ? 1.04 : 1
                    Ease on scale { duration: 500 }
                }

                Rectangle
                {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 44
                    gradient: Gradient
                    {
                        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
                    }
                }
                ShellText
                {
                    anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 10; right: change.left; rightMargin: 10 }
                    label: Config.wallpaperCurrent !== "" ? Config.wallpaperCurrent.substring(Config.wallpaperCurrent.lastIndexOf("/") + 1) : Tr.tr("settings.appearance.noWallpaper")
                    size: 12
                    color: "#ffffff"
                }
                Rectangle
                {
                    id: change
                    anchors { right: parent.right; rightMargin: 10; bottom: parent.bottom; bottomMargin: 8 }
                    width: changeText.implicitWidth + 22
                    height: 26
                    radius: 13
                    color: Qt.rgba(1, 1, 1, wallArea.containsMouse ? 0.28 : 0.16)
                    Tint on color {}
                    ShellText { id: changeText; anchors.centerIn: parent; label: Tr.tr("settings.appearance.change"); size: 11; color: "#ffffff" }
                }

                MouseArea
                {
                    id: wallArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: OverlayState.show("wallpapers")
                }
            }
        }
        SettingsRow
        {
            id: directoryRow

            label: Tr.tr("settings.appearance.wallpaperFolder")
            stacked: true

            Row
            {
                width: parent.width
                spacing: 8

                SettingsInput
                {
                    id: directoryInput
                    width: parent.width
                    text: Config.wallpaperDirectory
                    placeholderText: "~/Pictures/Wallpapers"
                    onEditingFinished: if (text.trim() !== "") Config.set("wallpaperDirectory", text.trim())
                }
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.apps")
        enabled: ServiceAppearance.loaded

        SettingsRow
        {
            visible: ServiceAppearance.error !== ""
            label: Tr.tr("settings.appearance.couldNotApply")
            badge: Tr.tr("common.error")
            badgeColor: Theme.colorCritical
            description: ServiceAppearance.error
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.gtkTheme")
            SettingsCombo
            {
                options: pageAppearance.withCurrent(ServiceAppearance.gtkThemes, ServiceAppearance.gtkTheme)
                current: ServiceAppearance.gtkTheme
                onSelected: value => ServiceAppearance.setGtkTheme(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.iconTheme")
            SettingsCombo
            {
                options: pageAppearance.withCurrent(ServiceAppearance.iconThemes, ServiceAppearance.iconTheme)
                current: ServiceAppearance.iconTheme
                onSelected: value => ServiceAppearance.setIconTheme(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.cursorTheme")
            SettingsCombo
            {
                options: pageAppearance.withCurrent(ServiceAppearance.cursorThemes, ServiceAppearance.cursorTheme)
                current: ServiceAppearance.cursorTheme
                onSelected: value => ServiceAppearance.setCursorTheme(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.cursorSize")
            SettingsStepper
            {
                value: ServiceAppearance.cursorSize
                from: 16; to: 64; step: 2; suffix: " px"
                onEdited: value => ServiceAppearance.setCursorSize(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.fontFamily")
            SettingsCombo
            {
                options: pageAppearance.withCurrent(ServiceAppearance.fonts, ServiceAppearance.fontFamily)
                current: ServiceAppearance.fontFamily
                onSelected: value => ServiceAppearance.setFontFamily(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.fontSize")
            SettingsStepper
            {
                value: ServiceAppearance.fontSize
                from: 6; to: 24; step: 1; suffix: " pt"
                onEdited: value => ServiceAppearance.setFontSize(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.reApplyToAllApps")
            SettingsButton { text: Tr.tr("settings.appearance.reApply"); icon: Icon.reload; onClicked: ServiceAppearance.reapply() }
        }
    }
}
