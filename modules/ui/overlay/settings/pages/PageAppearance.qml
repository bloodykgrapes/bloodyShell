pragma ComponentBehavior: Bound

import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageAppearance

    title: Tr.tr("common.appearance")
    subtitle: Tr.tr("settings.appearance.description")

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

                readonly property var themes: Registry.themeOptions
                width: parent.width
                spacing: 10

                Repeater
                {
                    model: themeCards.themes

                    Item
                    {
                        id: themeCard

                        required property var modelData
                        readonly property bool  current: Theme.light === light
                        readonly property var   colors: Theme.styles[modelData.value]
                        readonly property bool  light: modelData.value === Enums.ThemeLight
                        readonly property color ink: light ? "#1d1d1f" : "#ffffff"
                        readonly property color mark: Config.themeAccent ? Theme.accentBase : ink

                        width: Math.min(150, (themeCards.width - themeCards.spacing) / 2)
                        height: preview.height + themeCaption.implicitHeight + 8

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
                            id: themeCaption
                            anchors { horizontalCenter: parent.horizontalCenter; top: preview.bottom; topMargin: 6 }
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
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
            label: Tr.tr("settings.appearance.automaticColor")
            description: Tr.tr("settings.appearance.automaticColorHint")
            Toggle { checked: Config.themeAccent; onToggled: value => Config.set("themeAccent", value) }
        }

        SettingsRow
        {
            label: Tr.tr("settings.appearance.frameThickness")
            SettingsStepper
            {
                value: Theme.frameThickness
                from: 0; to: 8; step: 1; suffix: " px"
                onEdited: value => Config.set("frameThickness", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.animations")
            description: Tr.tr("settings.appearance.animationsHint")
            stacked: true

            SettingsStyleChoices
            {
                kind: "animation"
                options: Registry.animationOptions
                current: Config.themeAnimations
                onSelected: value => Config.set("themeAnimations", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.equalizerStyle")
            description: Tr.tr("settings.appearance.equalizerStyleHint")
            stacked: true

            Flow
            {
                id: equalizerStyles
                width: parent.width
                spacing: 10

                Repeater
                {
                    model: [Enums.EqualizerBars, Enums.EqualizerWaves]
                    SettingsStyleCard
                    {
                        required property int modelData
                        objectName: "equalizerStyle-" + modelData
                        kind: "equalizer"
                        width: Math.min(150, (equalizerStyles.width - equalizerStyles.spacing) / 2)
                        value: modelData
                        label: Tr.tr(modelData === Enums.EqualizerBars ? "settings.appearance.equalizerBars" : "settings.appearance.equalizerWaves")
                        current: Config.equalizerStyle === modelData
                        onClicked: Config.set("equalizerStyle", modelData)
                    }
                }
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.appearance.wallpaper")

        SettingsRow
        {
            objectName: "currentWallpaperRow"
            label: Tr.tr("settings.appearance.currentWallpaper")
            stacked: true

            WallpaperPreview
            {
                objectName: "currentWallpaperPreview"
                width: parent.width
                height: implicitHeight
                onClicked: OverlayState.show("wallpapers")
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
        SettingsRow
        {
            label: Tr.tr("settings.appearance.wallpaperTransition")
            SettingsCombo
            {
                objectName: "wallpaperTransitionSelector"
                options: [
                    {label: Tr.tr("common.off"), value: "none"},
                    {label: Tr.tr("settings.appearance.wallpaperSimple"), value: "simple"},
                    {label: Tr.tr("settings.appearance.wallpaperFade"), value: "fade"},
                    {label: Tr.tr("settings.appearance.wallpaperLeft"), value: "left"},
                    {label: Tr.tr("settings.appearance.wallpaperRight"), value: "right"},
                    {label: Tr.tr("settings.appearance.wallpaperTop"), value: "top"},
                    {label: Tr.tr("settings.appearance.wallpaperBottom"), value: "bottom"},
                    {label: Tr.tr("settings.appearance.wallpaperWipe"), value: "wipe"},
                    {label: Tr.tr("settings.appearance.wallpaperWave"), value: "wave"},
                    {label: Tr.tr("settings.appearance.wallpaperGrow"), value: "grow"},
                    {label: Tr.tr("settings.appearance.wallpaperCenter"), value: "center"},
                    {label: Tr.tr("settings.appearance.wallpaperAny"), value: "any"},
                    {label: Tr.tr("settings.appearance.wallpaperShrink"), value: "outer"},
                    {label: Tr.tr("settings.appearance.wallpaperRandom"), value: "random"}
                ]
                current: Config.wallpaperTransition
                onSelected: value => Config.set("wallpaperTransition", value)
            }
        }
        ShellText
        {
            width: parent.width
            label: ServiceAppearance.wallpaperError
            color: Theme.colorCritical
            wrapMode: Text.Wrap
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.applications")
        enabled: ServiceAppearance.loaded

        SettingsRow
        {
            visible: ServiceAppearance.error !== ""
            label: Tr.tr("settings.appearance.applyFailed")
            badge: Tr.tr("common.error")
            badgeColor: Theme.colorCritical
            description: ServiceAppearance.error
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
            label: Tr.tr("settings.appearance.appTheme")
            SettingsButton { text: Tr.tr("settings.appearance.reapply"); icon: Icon.reload; enabled: !ServiceAppearance.busy; onClicked: ServiceAppearance.reapply() }
        }
    }
}
