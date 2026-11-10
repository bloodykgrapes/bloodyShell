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

                readonly property var themes:
                [
                    { label: Tr.tr("settings.appearance.light"), value: Enums.ThemeLight },
                    { label: Tr.tr("settings.appearance.dark"), value: Enums.ThemeDark }
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
                        readonly property bool  current: Theme.light === light
                        readonly property var   colors: Theme.styles[modelData.value]
                        readonly property bool  light: modelData.value === Enums.ThemeLight
                        readonly property color ink: light ? "#1d1d1f" : "#ffffff"
                        readonly property color mark: Config.themeAccent ? Theme.accentBase : ink

                        width: Math.min(150, (themeCards.width - themeCards.spacing) / 2)
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
            label: Tr.tr("settings.appearance.border")
            Toggle { checked: Config.themeBorder; onToggled: value => Config.set("themeBorder", value) }
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
            description: Tr.tr("settings.appearance.animationsHint")
            stacked: true

            Row
            {
                spacing: 10
                Repeater
                {
                    model: [{ label: Tr.tr("settings.appearance.minimal"), value: Enums.AnimationsDisabled }, { label: Tr.tr("settings.appearance.standard"), value: Enums.AnimationsStandard }, { label: Tr.tr("settings.appearance.fluid"), value: Enums.AnimationsFluid }]
                    SettingsStyleCard
                    {
                        required property var modelData
                        kind: "animation"
                        value: modelData.value
                        label: modelData.label
                        current: Config.themeAnimations === modelData.value
                        onClicked: Config.set("themeAnimations", modelData.value)
                    }
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.equalizerStyle")
            description: Tr.tr("settings.appearance.equalizerStyleHint")
            stacked: true

            Row
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
            objectName: "qtThemeRow"
            label: Tr.tr("settings.appearance.qtTheme")
            Row
            {
                spacing: 8

                SettingsCombo
                {
                    objectName: "qtThemeSelector"
                    readonly property string selectedTheme: ServiceAppearance.qtThemes.find(name => name.toLowerCase() === ServiceAppearance.qtTheme.toLowerCase()) || ServiceAppearance.qtTheme
                    width: enableQt.visible ? 160 : implicitWidth
                    enabled: ServiceAppearance.qt6ct
                    options: pageAppearance.withCurrent(ServiceAppearance.qtThemes, selectedTheme)
                    current: selectedTheme
                    onSelected: value => ServiceAppearance.setQtTheme(value)
                }
                SettingsButton
                {
                    id: enableQt
                    objectName: "enableQtTheme"
                    visible: ServiceAppearance.qt6ct && !ServiceAppearance.qtActive && !ServiceAppearance.qtConfigured
                    text: Tr.tr("common.enable")
                    onClicked: ServiceAppearance.setQtTheme(ServiceAppearance.qtTheme)
                }
            }
        }
        SettingsPortals { id: portals }
        SettingsRow
        {
            objectName: "installedPortals"
            label: Tr.tr("settings.portals.installed")
            description: ServiceAppearance.portalBackends.length > 0
                ? ServiceAppearance.portalBackends.map(backend => portals.backendLabel(backend.id)).join(", ")
                : Tr.tr("settings.portals.empty")
            SettingsButton
            {
                objectName: "refreshPortals"
                text: Tr.tr("common.refresh")
                enabled: !ServiceAppearance.busy
                onClicked: ServiceAppearance.refresh(false)
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
            label: Tr.tr("settings.appearance.appTheme")
            SettingsButton { text: Tr.tr("settings.appearance.reapply"); icon: Icon.reload; enabled: !ServiceAppearance.busy; onClicked: ServiceAppearance.reapply() }
        }
    }
}
