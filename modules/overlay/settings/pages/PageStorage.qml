import QtQuick
import Quickshell.Widgets

import "../../../components"
import "../../../components/settings"
import "../../../core"
import "../../../services"

SettingsPage
{
    id: pageStorage

    Component.onCompleted: ServiceStorage.watchers++
    Component.onDestruction: { ServiceStorage.watchers--; ServiceStorage.cancelMount() }

    title: Tr.tr("common.storage")
    subtitle: Tr.tr("settings.storage.mountedDrivesAndHow")

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
        description: Tr.tr("settings.storage.advancedDescription")
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
            subtitle: Tr.tr("settings.storage.filesystemsOnly")

            SettingsRow
            {
                label: Tr.tr("settings.storage.detectedDisks")
                description: ServiceStorage.devicesLoaded && ServiceStorage.availableDevices.length === 0
                    ? Tr.tr("settings.storage.noUnmountedDisks") : Tr.tr("settings.storage.selectDisk")
                stacked: true

                Row
                {
                    width: parent.width
                    spacing: 8
                    SettingsCombo
                    {
                        width: Math.max(160, parent.width - refresh.width - parent.spacing)
                        enabled: !ServiceStorage.busy && !ServiceStorage.confirming
                        options: ServiceStorage.availableDevices.map(device => ({ label: ServiceStorage.deviceLabel(device), value: device.path }))
                        current: ServiceStorage.selectedPath
                        placeholderText: Tr.tr("settings.storage.selectDisk")
                        onSelected: value => ServiceStorage.selectDevice(value)
                    }
                    SettingsIconButton
                    {
                        id: refresh
                        icon: Icon.reload
                        enabled: !ServiceStorage.busy && !ServiceStorage.loading
                        onClicked: ServiceStorage.refresh()
                    }
                }
            }

            SettingsRow
            {
                label: Tr.tr("settings.storage.mountMode")
                description: ServiceStorage.mountMode === "once" ? Tr.tr("settings.storage.onceDescription") : Tr.tr("settings.storage.startupDescription")
                stacked: true
                SettingsChoices
                {
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
                description: Tr.tr("settings.storage.mountPointDescription")
                SettingsInput
                {
                    width: 280
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
                description: Tr.tr("settings.storage.readOnlyDescription")
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

            SettingsRow
            {
                visible: ServiceStorage.confirming
                label: Tr.tr("settings.storage.confirmMount")
                description: ServiceStorage.pending ? ServiceStorage.pending.label + "\n" + (ServiceStorage.pending.mode === "persistent"
                    ? Tr.tr("settings.storage.confirmStartup").arg(ServiceStorage.pending.target)
                    : Tr.tr("settings.storage.confirmOnce")) : ""
                stacked: true
                Row
                {
                    spacing: 8
                    SettingsButton
                    {
                        text: Tr.tr("common.cancel")
                        onClicked: ServiceStorage.cancelMount()
                    }
                    SettingsButton
                    {
                        text: Tr.tr("settings.storage.confirmAndMount")
                        enabled: !ServiceStorage.busy && !ServiceStorage.loading
                        onClicked: ServiceStorage.confirmMount()
                    }
                }
            }
        }
    }

    SettingsRow
    {
        visible: ServiceStorage.error !== ""
        label: Tr.tr("common.couldNotCompleteAction")
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
