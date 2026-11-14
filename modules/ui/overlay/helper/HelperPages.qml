pragma ComponentBehavior: Bound

import QtQuick

import "." as Content
import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"
import "../settings/components"
import "../settings/components" as Parts

Column
{
    id: helperPages

    property int currentPage: 0
    readonly property bool saving: ServiceDisplay.busy || ServiceDisplay.confirming || ServiceKeyboard.busy || ServiceDevices.mouseBusy
    readonly property string saveError: [ServiceDisplay.error, ServiceKeyboard.error, ServiceDevices.mouseError].filter(error => error !== "").join("\n")
    signal navigate(int index)

    function labelOf(options, value) { return options.find(option => option.value === value)?.label || String(value); }
    function layoutSummary(prefix)
    {
        return Config[prefix + "Enabled"] ? labelOf(Registry.edgeOptions, Config[prefix + "Side"]) + " · " + labelOf(Registry.frameOptions, Config[prefix + "Type"]) : Tr.tr("common.off");
    }

    width: parent.width
    spacing: 12

    Column
    {
        visible: helperPages.currentPage === 0
        width: parent.width
        spacing: 12
        Tip { objectName: "helperWelcome-1"; icon: Icon.settingsDisplay; title: Tr.tr("common.display"); description: Tr.tr("helper.displayHint"); onClicked: helperPages.navigate(1) }
        Tip { objectName: "helperWelcome-2"; icon: Icon.settingsAppearance; title: Tr.tr("common.appearance"); description: Tr.tr("helper.appearanceHint"); onClicked: helperPages.navigate(2) }
        Tip { objectName: "helperWelcome-3"; icon: Icon.settingsBar; title: Tr.tr("helper.layout"); description: Tr.tr("helper.layoutHint"); onClicked: helperPages.navigate(3) }
        Tip { objectName: "helperWelcome-4"; icon: Icon.keyboard; title: Tr.tr("helper.input"); description: Tr.tr("helper.inputHint"); onClicked: helperPages.navigate(4) }
        ShellText { width: parent.width; label: Tr.tr("helper.reopenHint"); size: 11; color: Theme.text3; wrapMode: Text.Wrap }
    }

    Loader
    {
        objectName: "helperDisplayLoader"
        active: helperPages.currentPage === 1
        width: parent.width
        height: item ? item.implicitHeight : 0
        sourceComponent: Parts.SettingsDisplayControls { objectName: "helperDisplay"; active: helperPages.currentPage === 1 }
    }

    Column
    {
        visible: helperPages.currentPage === 2
        width: parent.width
        spacing: 2
        SettingsRow
        {
            label: Tr.tr("settings.appearance.theme")
            SettingsChoices
            {
                objectName: "helperTheme"
                options: Registry.themeOptions
                current: Theme.light ? Enums.ThemeLight : Enums.ThemeDark
                onSelected: value => Config.set("themeStyle", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.automaticColor")
            description: Tr.tr("settings.appearance.automaticColorHint")
            Toggle { objectName: "helperAccent"; checked: Config.themeAccent; onToggled: value => Config.set("themeAccent", value) }
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
                namePrefix: "helperAnimation-"
                preferredCardWidth: 160
                current: Config.themeAnimations
                onSelected: value => Config.set("themeAnimations", value)
            }
        }
    }

    Column
    {
        visible: helperPages.currentPage === 3
        width: parent.width
        spacing: 20
        LayoutSection { prefix: "bar"; title: Tr.tr("common.bar") }
        LayoutSection { prefix: "dock"; title: Tr.tr("common.dock") }
    }

    Loader
    {
        objectName: "helperInputLoader"
        active: helperPages.currentPage === 4
        width: parent.width
        height: item ? item.implicitHeight : 0
        sourceComponent: Content.HelperInput {}
    }

    Column
    {
        visible: helperPages.currentPage === 5
        width: parent.width
        spacing: 20
        ShellText { width: parent.width; label: helperPages.saving ? Tr.tr("helper.saving") : Tr.tr("helper.savedHint"); wrapMode: Text.Wrap; color: Theme.text2 }
        SettingsRow
        {
            visible: helperPages.saveError !== ""
            label: Tr.tr("common.actionFailed")
            description: helperPages.saveError
            badge: Tr.tr("common.error")
            badgeColor: Theme.colorCritical
            SettingsButton { text: Tr.tr(ServiceDisplay.error !== "" ? "helper.reviewDisplay" : "helper.reviewInput"); onClicked: helperPages.navigate(ServiceDisplay.error !== "" ? 1 : 4) }
        }
        SettingsGroup
        {
            title: Tr.tr("common.display")
            visible: ServiceDisplay.outputs.length > 0
            Repeater
            {
                model: ServiceDisplay.outputs
                SettingsRow
                {
                    required property var modelData
                    readonly property var display: ServiceDisplay.stateOf(modelData.name)
                    objectName: "helperDisplaySummary-" + modelData.name
                    label: modelData.name
                    valueText: display.enabled ? display.mode + " · " + display.scale + "×" : Tr.tr("common.off")
                }
            }
        }
        SettingsGroup
        {
            title: Tr.tr("common.appearance")
            SettingsRow { label: Tr.tr("settings.appearance.theme"); valueText: Tr.tr(Theme.light ? "settings.appearance.light" : "settings.appearance.dark") }
            SettingsRow { label: Tr.tr("settings.appearance.automaticColor"); valueText: Tr.tr(Config.themeAccent ? "common.enabled" : "common.off") }
            SettingsRow { label: Tr.tr("settings.appearance.animations"); valueText: Tr.tr(Config.themeAnimations === Enums.AnimationsDisabled ? "settings.appearance.minimal" : Config.themeAnimations === Enums.AnimationsFluid ? "settings.appearance.fluid" : "settings.appearance.standard") }
        }
        SettingsGroup
        {
            title: Tr.tr("helper.layout")
            SettingsRow { objectName: "helperBarSummary"; label: Tr.tr("common.bar"); valueText: helperPages.layoutSummary("bar") }
            SettingsRow { objectName: "helperDockSummary"; label: Tr.tr("common.dock"); valueText: helperPages.layoutSummary("dock") }
        }
        SettingsGroup
        {
            title: Tr.tr("helper.input")
            SettingsRow { label: Tr.tr("settings.timeLanguage.keyboardLayouts"); description: ServiceKeyboard.layouts.map(layout => ServiceKeyboard.title(layout)).join(", ") }
            SettingsRow
            {
                objectName: "helperMouseSummary"
                visible: ServiceDevices.mouseLoaded && ServiceDevices.mouseAvailable
                label: Tr.tr("settings.devices.mouse")
                description: !visible ? "" : Tr.tr("helper.mouseSummary")
                    .arg(Tr.tr(ServiceDevices.mouse.profile === "adaptive" ? "settings.devices.adaptive" : "common.off"))
                    .arg(Math.round(ServiceDevices.mouse.speed * 100))
                    .arg(Math.abs(ServiceDevices.mouse.scrollVertical).toFixed(1))
                    .arg(Tr.tr(ServiceDevices.mouse.naturalScroll ? "common.enabled" : "common.off"))
            }
        }
    }

    component LayoutSection: SettingsGroup
    {
        id: section
        required property string prefix
        SettingsRow
        {
            label: Tr.tr("common.enabled")
            Toggle { objectName: "helper-" + section.prefix + "-enabled"; checked: Config[section.prefix + "Enabled"]; onToggled: value => Config.set(section.prefix + "Enabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.position")
            enabled: Config[section.prefix + "Enabled"]
            SettingsChoices
            {
                objectName: "helper-" + section.prefix + "-position"
                options: Registry.edgeOptions
                current: Config[section.prefix + "Side"]
                onSelected: value => Config.set(section.prefix + "Side", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("common.style")
            stacked: true
            enabled: Config[section.prefix + "Enabled"]
            SettingsStyleChoices
            {
                kind: "frame"
                options: Registry.frameOptions
                namePrefix: "helper-" + section.prefix + "-style-"
                current: Config[section.prefix + "Type"]
                onSelected: value => Config.set(section.prefix + "Type", value)
            }
        }
    }

    component Tip: Rectangle
    {
        id: tip
        property string icon: ""
        property string title: ""
        property string description: ""
        signal clicked()
        width: parent.width
        height: Math.max(42, copy.implicitHeight) + 28
        radius: Theme.radiusLarge
        color: Theme.settingsColorCard
        activeFocusOnTab: true
        Keys.onReturnPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
        Keys.onEnterPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
        Keys.onSpacePressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
        Accessible.role: Accessible.Button
        Accessible.name: title + ", " + description
        Accessible.onPressAction: clicked()
        Rectangle
        {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.colorHover
            opacity: tipHover.hovered || tip.activeFocus ? 1 : 0
            Smooth on opacity {}
        }
        ShellIcon { x: 16; y: 18; icon: tip.icon; size: 22 }
        Column
        {
            id: copy
            x: 54
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 16
            spacing: 6
            Item
            {
                width: parent.width
                height: tipTitle.implicitHeight
                ShellText
                {
                    id: tipTitle
                    width: Math.max(0, parent.width - chevron.width - 12)
                    label: tip.title; size: 13; font.weight: Font.DemiBold; color: Theme.text1
                    wrapMode: Text.Wrap
                }
                ShellIcon { id: chevron; anchors.right: parent.right; icon: Icon.chevronRight; size: 12 }
            }
            ShellText { width: parent.width; label: tip.description; size: 12; wrapMode: Text.Wrap; color: Theme.text2 }
        }
        HoverHandler { id: tipHover }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tip.clicked() }
    }
}
