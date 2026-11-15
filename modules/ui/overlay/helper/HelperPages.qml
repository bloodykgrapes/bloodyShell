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
                border.width: 1
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
                    icon: message.ready ? Icon.check : Icon.settingsGeneral
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
                    SettingsButton
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

    Column
    {
        visible: helperPages.currentPage === 3
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
            Toggle { objectName: "helperAccent"; checked: Config.themeAccent; onToggled: value => Config.set("themeAccent", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.appearance.animations")
            SettingsChoices
            {
                objectName: "helperAnimations"
                options: Registry.animationOptions
                current: Config.themeAnimations
                onSelected: value => Config.set("themeAnimations", value)
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

    SettingsGroup
    {
        visible: helperPages.currentPage === 5 && helperPages.saveError !== ""
        SettingsRow
        {
            label: Tr.tr("common.actionFailed")
            description: helperPages.saveError
            SettingsButton
            {
                text: Tr.tr(ServiceDisplay.error !== "" ? "helper.reviewDisplay" : "helper.reviewTimeLanguage")
                onClicked: helperPages.navigate(ServiceDisplay.error !== "" ? 2 : 1)
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
    }
}
