pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageAbout

    title: Tr.tr("common.about")
    subtitle: Tr.tr("settings.about.description")

    readonly property string projectUrl: "https://github.com/" + ServiceUpdate.repo
    readonly property string missing: !ServiceSystem.detailsRequested || ServiceSystem.loading ? Tr.tr("common.loading") : Tr.tr("settings.about.unavailable")

    onActiveChanged: if (active) ServiceSystem.ensureDetails()
    Component.onCompleted: if (active) ServiceSystem.ensureDetails()

    component InfoRow: SettingsRow
    {
        id: infoRow

        property string detail: ""
        readonly property string display: detail || pageAbout.missing
        stacked: display.includes("\n") || measure.advanceWidth > width * 0.45
        valueText: stacked ? "" : display

        TextMetrics { id: measure; text: infoRow.display; font: detailText.font }
        Item
        {
            visible: infoRow.stacked
            width: infoRow.stacked ? Math.max(0, infoRow.width - infoRow.inset * 2) : 0
            height: infoRow.stacked ? detailText.implicitHeight : 0
            ShellText
            {
                id: detailText
                width: parent.width
                label: infoRow.stacked ? infoRow.display : ""
                size: 12
                color: Theme.text2
                wrapMode: Text.Wrap
            }
        }
    }

    SettingsGroup
    {
        Item
        {
            id: hero
            objectName: "aboutShellCard"
            width: parent.width
            height: identity.implicitHeight + 40

            SettingsTile { row: hero }

            Column
            {
                id: identity
                x: 20; y: 20
                width: parent.width - 40
                spacing: 18

                Row
                {
                    width: parent.width
                    spacing: 18

                    ClippingRectangle
                    {
                        width: 64; height: 64; radius: 17
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        Image
                        {
                            anchors.fill: parent
                            source: Qt.resolvedUrl("../../../../../assets/icons/logo.png")
                            sourceSize: Qt.size(128, 128)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    Column
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width - 82)
                        spacing: 5

                        ShellText { width: parent.width; label: "bloodyShell"; size: 26; font.weight: Font.DemiBold; color: Theme.text1 }
                        ShellText
                        {
                            width: parent.width
                            label: ServiceUpdate.versionReady ? Tr.tr("settings.about.versionLabel").arg(ServiceUpdate.version) : Tr.tr("common.loading")
                            size: 12
                            color: Theme.text2
                        }
                        ShellText
                        {
                            width: parent.width
                            label: Tr.tr(ServiceUpdate.installed ? "settings.about.installed" : "settings.updates.developmentCopy")
                            size: 11
                            color: Theme.text3
                        }
                    }
                }

                ShellText
                {
                    width: parent.width
                    label: Tr.tr("settings.about.shellDescription")
                    color: Theme.text2
                    wrapMode: Text.Wrap
                }

                Flow
                {
                    width: parent.width
                    spacing: 8
                    SettingsButton { icon: Icon.update; text: Tr.tr("common.updates"); onClicked: ServiceUpdate.showPage() }
                    SettingsButton { text: Tr.tr("settings.about.source"); onClicked: Qt.openUrlExternally(pageAbout.projectUrl) }
                    SettingsButton { text: Tr.tr("settings.about.documentation"); onClicked: Qt.openUrlExternally(pageAbout.projectUrl + "/wiki") }
                }
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.system")

        InfoRow { label: Tr.tr("settings.about.operatingSystem"); detail: ServiceSystem.release.PRETTY_NAME || ServiceSystem.release.NAME || "Linux" }
        InfoRow { label: Tr.tr("settings.about.kernel"); detail: ServiceSystem.kernel }
        InfoRow { label: Tr.tr("settings.about.compositor"); detail: "niri" + (ServiceSystem.compositor ? " " + ServiceSystem.compositor : "") }
        InfoRow { label: Tr.tr("settings.about.runtime"); detail: "Quickshell" + (Qt.application.version ? " " + Qt.application.version : "") }
        InfoRow { label: Tr.tr("settings.about.computerName"); detail: ServiceSystem.hostname }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.about.hardware")

        InfoRow { objectName: "aboutDevice"; visible: ServiceSystem.device !== ""; label: Tr.tr("settings.about.device"); detail: ServiceSystem.device }
        InfoRow
        {
            objectName: "aboutProcessor"
            label: Tr.tr("settings.about.processor")
            detail: ServiceSystem.processor
            description: ServiceSystem.threads > 0 ? Tr.tr("settings.about.threads").arg(ServiceSystem.threads) : ""
        }
        InfoRow { objectName: "aboutGraphics"; label: Tr.tr("settings.about.graphics"); detail: ServiceSystem.graphics.join("\n") }
        InfoRow { label: Tr.tr("settings.about.memory"); detail: ServiceSystem.memoryKiB > 0 ? (ServiceSystem.memoryKiB / 1048576).toLocaleString(Tr.locale, "f", 1) + " GiB" : "" }
        SettingsRow
        {
            label: Tr.tr("settings.about.systemInformation")
            SettingsButton
            {
                objectName: "aboutRefresh"
                icon: Icon.reload
                text: Tr.tr(ServiceSystem.loading ? "common.refreshing" : "common.refresh")
                enabled: !ServiceSystem.loading
                onClicked: ServiceSystem.refresh()
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.about.project")

        SettingsRow
        {
            label: Tr.tr("settings.about.license")
            description: "GPL-3.0"
            SettingsButton { text: Tr.tr("common.open"); onClicked: Qt.openUrlExternally(pageAbout.projectUrl + "/blob/main/LICENSE") }
        }
    }
}
