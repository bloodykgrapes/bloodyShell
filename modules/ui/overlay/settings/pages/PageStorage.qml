import QtQuick
import Quickshell.Widgets

import "../../../../animations"
import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageStorage

    onActiveChanged: ServiceStorage.setWatching(pageStorage, active)
    Component.onCompleted: ServiceStorage.setWatching(pageStorage, active)
    Component.onDestruction: { ServiceStorage.setWatching(pageStorage, false); ServiceStorage.cancelMount() }

    title: Tr.tr("common.storage")
    subtitle: Tr.tr("settings.storage.description")

    SettingsConfirmation
    {
        objectName: "mountConfirmation"
        host: pageStorage
        visible: pageStorage.active && ServiceStorage.confirming
        title: Tr.tr("settings.storage.confirmMount")
        description: ServiceStorage.pending ? ServiceStorage.pending.label + "\n" + (ServiceStorage.pending.mode === "persistent"
            ? Tr.tr("settings.storage.confirmStartup").arg(ServiceStorage.pending.target)
            : Tr.tr("settings.storage.confirmOnce")) : ""
        acceptText: Tr.tr("settings.storage.mount")
        acceptEnabled: !ServiceStorage.busy && !ServiceStorage.loading
        onAccepted: ServiceStorage.confirmMount()
        onRejected: ServiceStorage.cancelMount()
    }

    SettingsGroup
    {
        title: Tr.tr("settings.storage.volumes")

        SettingsRow
        {
            visible: ServiceStorage.volumesLoaded && ServiceStorage.volumes.length === 0
            label: Tr.tr("settings.storage.noDrivesFound")
        }

        Repeater
        {
            model: ServiceStorage.volumeModel

            SettingsRow
            {
                id: volume

                required property var modelData

                readonly property real  share: modelData.used + modelData.free > 0 ? Math.min(1, modelData.used / (modelData.used + modelData.free)) : 0
                readonly property color tint:  share > 0.9 ? Theme.colorCritical : share > 0.75 ? Theme.colorWarning : Theme.colorAccent

                label: modelData.target === "/" ? Tr.tr("settings.storage.system") : modelData.target
                description: modelData.device + " · " + modelData.type
                stacked: true

                Item
                {
                    width: parent.width
                    height: 36

                    ClippingRectangle
                    {
                        id: usage

                        width: parent.width - open.width - 10
                        height: parent.height
                        radius: Theme.radiusMedium
                        color: Theme.colorField

                        Rectangle
                        {
                            width: parent.width * volume.share
                            height: parent.height
                            color: Qt.rgba(volume.tint.r, volume.tint.g, volume.tint.b, 0.3)
                            Ease on width { duration: Theme.animationDurationControl }
                        }

                        ShellText
                        {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            label: Tr.tr("settings.storage.freeOf").arg(ServiceStorage.size(volume.modelData.free)).arg(ServiceStorage.size(volume.modelData.size))
                            size: 12
                            color: Theme.text1
                        }
                        ShellText
                        {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            label: Math.round(volume.share * 100) + "%"
                            size: 12
                            color: Theme.text2
                        }
                    }

                    SettingsButton
                    {
                        id: open
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: Tr.tr("common.open")
                        onClicked: Qt.openUrlExternally("file://" + volume.modelData.target)
                    }
                }
            }
        }
    }
    SettingsDisclosure
    {
        title: Tr.tr("settings.storage.advanced")
        description: Tr.tr("settings.storage.advancedHint")
        icon: Icon.settingsStorage
        onExpandedChanged:
        {
            if (!expanded) ServiceStorage.cancelMount();
            else if (Config.animationsFluid) mountOptions.enter(0);
            else mountOptions.opacity = 1;
        }

        SettingsGroup
        {
            id: mountOptions
            title: Tr.tr("settings.storage.mountDisk")
            subtitle: Tr.tr("settings.storage.detectedHint")

            SettingsRow
            {
                label: Tr.tr("settings.storage.detectedDisks")
                description: ServiceStorage.devicesLoaded && ServiceStorage.availableDevices.length === 0
                    ? Tr.tr("settings.storage.noUnmountedDisks") : Tr.tr("settings.storage.selectDisk")

                Item
                {
                    id: diskControls
                    implicitWidth: diskChoice.preferredWidth + refresh.implicitWidth + 8
                    implicitHeight: Math.max(diskChoice.height, refresh.height)
                    width: Theme.controlWidth(diskControls, implicitWidth)
                    SettingsCombo
                    {
                        id: diskChoice
                        anchors.verticalCenter: parent.verticalCenter
                        preferredWidth: 300
                        width: Math.max(0, parent.width - refresh.width - 8)
                        enabled: !ServiceStorage.busy && !ServiceStorage.confirming
                        options: ServiceStorage.availableDevices.map(device => ({ label: ServiceStorage.deviceLabel(device), value: device.path }))
                        current: ServiceStorage.selectedPath
                        placeholderText: Tr.tr("settings.storage.selectDisk")
                        onSelected: value => ServiceStorage.selectDevice(value)
                    }
                    SettingsIconButton
                    {
                        id: refresh
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        icon: Icon.reload
                        enabled: !ServiceStorage.busy && !ServiceStorage.loading
                        onClicked: ServiceStorage.refresh()
                    }
                }
            }

            SettingsRow
            {
                label: Tr.tr("settings.storage.mountMode")
                description: ServiceStorage.mountMode === "once" ? Tr.tr("settings.storage.onceHint") : Tr.tr("settings.storage.startupHint")
                SettingsChoices
                {
                    objectName: "storageMountMode"
                    enabled: !ServiceStorage.busy && !ServiceStorage.confirming
                    options: [{ label: Tr.tr("settings.storage.mountOnce"), value: "once" }, { label: Tr.tr("settings.storage.mountAtStartup"), value: "persistent" }]
                    current: ServiceStorage.mountMode
                    onSelected: value => ServiceStorage.setMountMode(value)
                }
            }

            SettingsRow
            {
                visible: ServiceStorage.mountMode === "persistent"
                label: Tr.tr("settings.storage.mountPoint")
                description: Tr.tr("settings.storage.mountPointHint")
                SettingsInput
                {
                    preferredWidth: 280
                    enabled: !ServiceStorage.busy && !ServiceStorage.confirming
                    text: ServiceStorage.mountPoint
                    placeholderText: "/mnt/data"
                    onTextEdited: value => ServiceStorage.setMountPoint(value)
                }
            }

            SettingsRow
            {
                visible: ServiceStorage.selectedDevice !== null && ServiceStorage.selectedDevice.readOnly
                label: Tr.tr("settings.storage.readOnly")
                description: Tr.tr("settings.storage.readOnlyHint")
            }

            SettingsRow
            {
                visible: !ServiceStorage.confirming
                label: ServiceStorage.busy ? Tr.tr("common.working") : Tr.tr("settings.storage.readyToMount")
                SettingsButton
                {
                    text: Tr.tr("settings.storage.mount")
                    enabled: ServiceStorage.selectedDevice !== null && !ServiceStorage.selectedDevice.mounted && !ServiceStorage.busy && !ServiceStorage.loading
                    onClicked: ServiceStorage.prepareMount()
                }
            }
        }
    }

    SettingsRow
    {
        visible: ServiceStorage.error !== ""
        label: Tr.tr("common.actionFailed")
        description: ServiceStorage.error
        badge: Tr.tr("common.error")
        badgeColor: Theme.colorCritical
    }

    SettingsRow
    {
        visible: ServiceStorage.message !== ""
        label: Tr.tr("common.status")
        description: ServiceStorage.message
    }

}
