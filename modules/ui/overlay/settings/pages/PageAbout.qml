pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

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

    property bool confirmReset: false

    SettingsConfirmation
    {
        objectName: "resetConfirmation"
        host: pageAbout
        visible: pageAbout.active && pageAbout.confirmReset
        title: Tr.tr("settings.about.resetAllSettings")
        description: Tr.tr("settings.about.resetHint")
        acceptText: Tr.tr("settings.about.reset")
        danger: true
        onAccepted: { pageAbout.confirmReset = false; Config.reset(); }
        onRejected: pageAbout.confirmReset = false
    }

    component AboutCard: Rectangle
    {
        radius: Theme.radiusLarge
        color: Theme.settingsColorCard
    }

    component IdentityBanner: AboutCard
    {
        id: banner

        property string caption: ""
        property string name: ""
        property string subtitle: ""
        property url artwork
        property string fallbackIcon: ""
        property bool branded: false

        width: parent.width
        height: Math.max(96, identity.implicitHeight + 32)

        Column
        {
            id: identity
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
            spacing: 8

            Rectangle
            {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 60
                height: 60
                radius: Theme.controlRadius
                color: Theme.settingsColorCard

                Image
                {
                    id: artworkImage
                    anchors { fill: parent; margins: banner.branded ? 4 : 10 }
                    source: banner.artwork
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(112, 112)
                    asynchronous: true
                }

                ShellIcon
                {
                    anchors.centerIn: parent
                    visible: artworkImage.status !== Image.Ready && icon !== ""
                    icon: banner.fallbackIcon
                    size: 28
                }
            }

            Column
            {
                width: parent.width
                spacing: 4

                ShellText { width: parent.width; label: banner.caption; size: 11; color: Theme.text3; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
                ShellText
                {
                    width: parent.width
                    label: banner.name
                    size: banner.branded ? 28 : 22
                    font.family: banner.branded ? Theme.fontBrand : Theme.fontText
                    font.weight: Font.DemiBold
                    color: Theme.text1
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
                ShellText { width: parent.width; label: banner.subtitle; size: 12; color: Theme.text2; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
            }
        }
    }

    component DetailGrid: GridLayout
    {
        width: parent.width
        columns: width >= 360 ? 2 : 1
        columnSpacing: 8
        rowSpacing: 8
    }

    component DetailTile: AboutCard
    {
        id: tile

        property string label: ""
        property string detail: ""
        property string description: ""
        property string icon: ""
        readonly property string display: detail || pageAbout.missing

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 0
        implicitHeight: details.implicitHeight + 24
        height: implicitHeight

        Column
        {
            id: details
            x: 12; y: 12
            width: Math.max(0, parent.width - 24)
            spacing: 6

            RowLayout
            {
                width: parent.width
                spacing: 8

                Rectangle
                {
                    visible: tile.icon !== ""
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Theme.radiusSmall
                    color: Theme.controlColorActive
                    ShellIcon { anchors.centerIn: parent; icon: tile.icon; size: 16 }
                }
                ShellText
                {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    label: tile.label
                    size: 11
                    color: Theme.text3
                    wrapMode: Text.Wrap
                }
            }
            ShellText
            {
                objectName: "aboutDetailValue"
                width: parent.width
                label: tile.display
                size: tile.icon !== "" ? 14 : 13
                font.weight: Font.DemiBold
                color: Theme.text1
                wrapMode: Text.Wrap
            }
            ShellText { width: parent.width; label: tile.description; size: 11; color: Theme.text3; wrapMode: Text.Wrap }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("common.system")

        Column
        {
            width: parent.width
            spacing: 8

            IdentityBanner
            {
                caption: Tr.tr("settings.about.operatingSystem")
                name: ServiceSystem.release.PRETTY_NAME || ServiceSystem.release.NAME || "Linux"
                artwork: ServiceSystem.logo
                fallbackIcon: Icon.settingsDesktop
            }

            DetailGrid
            {
                DetailTile { label: Tr.tr("settings.about.kernel");       detail: ServiceSystem.kernel }
                DetailTile { label: Tr.tr("settings.about.compositor");   detail: ServiceSystem.compositor || ServiceCompositor.displayName }
                DetailTile { label: Tr.tr("settings.about.runtime");      detail: "Quickshell" + (Qt.application.version ? " " + Qt.application.version : "") }
                DetailTile { label: Tr.tr("settings.about.computerName"); detail: ServiceSystem.hostname }
            }

            DetailGrid
            {
                DetailTile
                {
                    objectName: "aboutDevice"
                    visible: ServiceSystem.device !== ""
                    label: Tr.tr("settings.about.device")
                    detail: ServiceSystem.device
                    icon: Icon.settingsDesktop
                }
                DetailTile
                {
                    label: Tr.tr("settings.about.memory")
                    detail: ServiceSystem.memoryKiB > 0 ? (ServiceSystem.memoryKiB / 1048576).toLocaleString(Tr.locale, "f", 1) + " GiB" : ""
                    icon: Icon.memory
                }
                DetailTile
                {
                    objectName: "aboutProcessor"
                    label: Tr.tr("settings.about.processor")
                    detail: ServiceSystem.processor
                    description: ServiceSystem.threads > 0 ? Tr.tr("settings.about.threads").arg(ServiceSystem.threads) : ""
                    icon: Icon.processor
                }
                DetailTile
                {
                    objectName: "aboutGraphics"
                    label: Tr.tr("settings.about.graphics")
                    detail: ServiceSystem.graphics.join("\n")
                    icon: Icon.settingsDisplay
                }
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("common.shell")

        IdentityBanner
        {
            objectName: "aboutShellCard"
            branded: true
            artwork: Qt.resolvedUrl("../../../../../assets/icons/logo.png")
            name: "bloodyShell"
            caption: Tr.tr(ServiceUpdate.installed ? "settings.about.installed" : "settings.updates.developmentCopy")
            subtitle: (ServiceUpdate.versionReady ? Tr.tr("settings.about.versionLabel").arg(ServiceUpdate.version) : Tr.tr("common.loading")) + " · GPL-3.0"
        }

        SettingsRow
        {
            label: Tr.tr("settings.about.documentation")

            Button
            {
                text: Tr.tr("common.open")
                Accessible.name: Tr.tr("settings.about.documentation")
                onClicked: Qt.openUrlExternally(pageAbout.projectUrl + "/wiki")
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.structure.reportBug")
            Button
            {
                text: Tr.tr("common.open")
                Accessible.name: Tr.tr("settings.structure.reportBug")
                onClicked: Qt.openUrlExternally(pageAbout.projectUrl + "/issues/new")
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.about.source")

            Button
            {
                text: Tr.tr("common.open")
                Accessible.name: Tr.tr("settings.about.source")
                onClicked: Qt.openUrlExternally(pageAbout.projectUrl)
            }
        }
        SettingsRow
        {
            label: Tr.tr("helper.setup")
            description: Tr.tr("helper.openHint")
            Button { text: Tr.tr("common.open"); icon: Icon.setup; onClicked: OverlayState.show("helper") }
        }
        SettingsRow
        {
            label: Tr.tr("settings.about.debugLogging")
            description: Tr.tr("settings.about.debugLoggingHint")

            Toggle
            {
                checked: Config.debug
                onToggled: value => Config.set("debug", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.about.resetAllSettings")
            description: Tr.tr("settings.about.resetHint")

            Button
            {
                danger: true
                objectName: "requestReset"
                text: Tr.tr("settings.about.reset")
                onClicked: pageAbout.confirmReset = true
            }
        }
    }
}
