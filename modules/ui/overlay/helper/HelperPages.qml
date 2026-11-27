pragma ComponentBehavior: Bound

import QtQuick

import "." as Content
import "../../../common"
import "../../../core"
import "../../../services"
import "../settings/components"

Column
{
    id: helperPages

    property int currentPage: 0
    property real availableHeight: 0
    readonly property bool saving: ServiceDisplay.busy || ServiceDisplay.confirming || ServiceRegion.busy
    readonly property string saveError: [ServiceDisplay.error, ServiceRegion.error].filter(error => error !== "").join("\n")
    signal navigate(int index)

    width: parent.width
    spacing: 12

    Item
    {
        id: message
        objectName: "helperMessage"
        visible: helperPages.currentPage === 0 || helperPages.currentPage === 5
        readonly property bool complete: helperPages.currentPage === 5
        readonly property bool ready: complete && !helperPages.saving && !helperPages.saveError
        width: parent.width
        implicitHeight: Math.max(helperPages.availableHeight, visual.implicitHeight + 24)

        Column
        {
            id: visual
            anchors.centerIn: parent
            width: Math.min(520, parent.width)
            spacing: 18

            Rectangle
            {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 88; height: 88; radius: 28
                color: Theme.colorSelection
                border.width: Theme.panelBorderWidth
                border.color: Theme.colorPanelEdge
                Image
                {
                    anchors.centerIn: parent
                    width: 64; height: 64
                    visible: !message.complete
                    source: Qt.resolvedUrl("../../../../assets/icons/logo.png")
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectFit
                }
                ShellIcon
                {
                    anchors.centerIn: parent
                    visible: message.complete
                    icon: message.ready ? Icon.check : Icon.setup
                    size: 38
                }
            }

            Column
            {
                width: parent.width
                spacing: 10
                ShellText
                {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    label: message.ready ? Tr.tr("helper.readyTitle") : Tr.tr(message.complete ? "helper.ready" : "helper.welcome")
                    size: 28
                    color: Theme.text1
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
                ShellText
                {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: message.ready
                    label: Tr.tr("helper.thanks")
                    size: 16
                    color: Theme.text1
                    wrapMode: Text.Wrap
                }
                ShellText
                {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    label: !message.complete ? Tr.tr("helper.welcomeHint") : helperPages.saving ? Tr.tr("helper.saving")
                        : helperPages.saveError || Tr.tr("helper.readyHint")
                    size: 13
                    color: Theme.text2
                    wrapMode: Text.Wrap
                }
            }

            Row
            {
                width: parent.width
                spacing: 10
                visible: !message.complete
                Repeater
                {
                    model: [
                        {label: Tr.tr("common.timeLanguage"), icon: Icon.settingsTimeLanguage},
                        {label: Tr.tr("common.display"), icon: Icon.settingsDisplay},
                        {label: Tr.tr("common.appearance"), icon: Icon.settingsAppearance}
                    ]
                    Rectangle
                    {
                        required property var modelData
                        width: (visual.width - 20) / 3
                        height: 86; radius: 14
                        color: Theme.colorField
                        ShellIcon { anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 14 } icon: modelData.icon; size: 22 }
                        ShellText { x: 8; y: 46; width: parent.width - 16; horizontalAlignment: Text.AlignHCenter; label: modelData.label; size: 11; wrapMode: Text.Wrap }
                    }
                }
            }

            Rectangle
            {
                visible: message.ready
                width: parent.width
                height: issueContent.implicitHeight + 28
                radius: 14
                color: Theme.colorField
                Column
                {
                    id: issueContent
                    x: 14; y: 14; width: parent.width - 28
                    spacing: 10
                    ShellText { width: parent.width; horizontalAlignment: Text.AlignHCenter; label: Tr.tr("helper.issueHint"); wrapMode: Text.Wrap; size: 12 }
                    Button
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Tr.tr("helper.reportIssue")
                        onClicked: Qt.openUrlExternally("https://github.com/" + ServiceUpdate.repo + "/issues/new/choose")
                    }
                }
            }
        }
    }

    Loader
    {
        objectName: "helperRegionLoader"
        active: helperPages.currentPage === 1
        width: parent.width
        height: item ? item.implicitHeight : 0
        sourceComponent: Content.HelperRegion {}
    }

    Loader
    {
        objectName: "helperDisplayLoader"
        active: helperPages.currentPage === 2
        width: parent.width
        height: item ? item.implicitHeight : 0
        sourceComponent: SettingsDisplayControls { objectName: "helperDisplay"; active: helperPages.currentPage === 2 }
    }

    SettingsRowGroup
    {
        visible: helperPages.currentPage === 3
        title: Tr.tr("settings.appearance.theme")

        SettingsRow
        {
            label: Tr.tr("settings.structure.scheme")
            stacked: true

            SettingsStyleChoices
            {
                objectName: "helperTheme"
                kind: "theme"
                options: Registry.themeOptions
                namePrefix: "helperThemeStyle-"
                current: Config.themeStyle
                onSelected: value => Config.set("themeStyle", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.accent")
            description: Tr.tr("settings.appearance.accentHint")

            SettingsChoices
            {
                objectName: "helperAccentMode"
                options: Registry.accentModeOptions
                current: Config.themeAccentMode
                onSelected: value => Config.set("themeAccentMode", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.accentHue")
            visible: Config.themeAccentMode === Enums.AccentCustom

            SettingsSlider
            {
                objectName: "helperAccentHue"
                from: 0
                to: 360
                step: 1
                hue: true
                value: Config.accentHue
                valueText: Math.round(shown) + "°"
                onMoved: value => Config.set("accentHue", value)
            }
        }
    }

    SettingsRowGroup
    {
        visible: helperPages.currentPage === 3
        title: Tr.tr("settings.structure.motion")

        SettingsRow
        {
            label: Tr.tr("settings.structure.reduceMotion")
            description: Tr.tr("settings.appearance.reduceMotionHint")

            Toggle
            {
                objectName: "helperMotionReduce"
                checked: Config.motionReduce
                onToggled: value => Config.set("motionReduce", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.motionStyle")
            stacked: true
            enabled: !Config.motionReduce

            SettingsStyleChoices
            {
                objectName: "helperMotionStyle"
                kind: "animation"
                options: Registry.motionStyleOptions
                namePrefix: "helperMotionStyle-"
                current: Config.motionStyle
                onSelected: value => Config.set("motionStyle", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.motionSpeed")
            description: Tr.tr("settings.appearance.motionSpeedHint")
            enabled: !Config.motionReduce && Config.motionStyle !== Enums.MotionDirect

            SettingsSlider
            {
                objectName: "helperMotionSpeed"
                from: 0.25
                to: 2
                step: 0.05
                value: Config.motionSpeed
                valueText: shown.toFixed(2) + "×"
                onMoved: value => Config.set("motionSpeed", value)
            }
        }
    }

    Column
    {
        visible: helperPages.currentPage === 4
        width: parent.width
        spacing: 20
        LayoutSection { prefix: "bar"; title: Tr.tr("common.bar") }
        LayoutSection { prefix: "dock"; title: Tr.tr("common.dock") }
    }

    SettingsRowGroup
    {
        visible: helperPages.currentPage === 5 && helperPages.saveError !== ""
        SettingsRow
        {
            label: Tr.tr("common.actionFailed")
            description: helperPages.saveError
            Button
            {
                text: Tr.tr(ServiceDisplay.error !== "" ? "helper.reviewDisplay" : "helper.reviewTimeLanguage")
                onClicked: helperPages.navigate(ServiceDisplay.error !== "" ? 2 : 1)
            }
        }
    }

    component LayoutSection: SettingsRowGroup
    {
        id: section
        required property string prefix
        readonly property string styleKey: prefix + "Type"
        readonly property int style: Config[styleKey]
        property int enabledStyle: Enums.InFrame

        SettingsRow
        {
            visible: section.prefix === "dock"
            label: Tr.tr("common.enabled")
            Toggle
            {
                objectName: "helper-" + section.prefix + "-enabled"
                checked: section.style !== Enums.PanelDisabled
                onToggled: value =>
                {
                    if (!value) section.enabledStyle = section.style;
                    Config.set(section.styleKey, value ? section.enabledStyle : Enums.PanelDisabled);
                }
            }
        }
        SettingsRow
        {
            visible: section.prefix === "bar"
            label: Tr.tr("common.style")
            SettingsChoices
            {
                options: Registry.barStyleOptions
                current: Config.barType
                onSelected: value => Config.set("barType", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("common.position")
            enabled: section.style !== Enums.PanelDisabled
            SettingsChoices
            {
                objectName: "helper-" + section.prefix + "-position"
                options: Registry.edgeOptions
                current: Config[section.prefix + "Side"]
                onSelected: value => Config.set(section.prefix + "Side", value)
            }
        }
    }
}
