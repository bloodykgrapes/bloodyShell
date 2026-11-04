import QtQuick
import Quickshell

import "core"
import "services"

ShellRoot
{
    id: tests
    property int phase: 0
    property int volumeDelegates: 0

    Item
    {
        Repeater
        {
            id: volumeRows
            model: ServiceStorage.volumeModel
            Item
            {
                required property var modelData
                readonly property real share: modelData.used / (modelData.used + modelData.free)
                Component.onCompleted: tests.volumeDelegates++
            }
        }
    }

    function check(condition, message)
    {
        if (!condition)
        {
            console.error("REGRESSION_FAILED", message);
            Qt.quit();
            throw new Error(message);
        }
    }

    function begin()
    {
        check(ServiceStorage.udisksCommand === Quickshell.env("BLOODYSHELL_TEST_BIN") + "/udisksctl", "only fake mount tool may run");
        check(ServiceStorage.pkexecCommand === Quickshell.env("BLOODYSHELL_TEST_BIN") + "/pkexec", "only fake authorizer may run");
        check(ServiceStorage.devices.length === 4, "nested filesystem discovery excludes swap and locked containers and deduplicates paths");
        check(ServiceStorage.availableDevices.length === 3, "mounted filesystem excluded from mount choices");
        check(ServiceStorage.volumes[0].target === "/" && ServiceStorage.volumes.length === 2, "mounted usage excludes pseudo filesystems");
        check(ServiceStorage.volumes[1].target === "/mnt/With Spaces", "mount paths with spaces stay intact");
        const entries = ServiceStorage.parseStartupMounts("UUID=old /mnt/Some\\040Data ext4 defaults 0 0\n");
        check(entries[0].target === "/mnt/Some Data", "fstab fields decoded");
        ServiceStorage.selectDevice("/dev/test-root");
        ServiceStorage.prepareMount();
        check(!ServiceStorage.confirming, "mounted system disk rejected");
        ServiceStorage.selectDevice("/dev/test-data");
        ServiceStorage.setMountMode("persistent");
        ServiceStorage.setMountPoint("/etc/data");
        ServiceStorage.prepareMount();
        check(!ServiceStorage.confirming && ServiceStorage.error === "service.storage.invalidMountPoint", "protected mount point rejected");
        ServiceStorage.setMountPoint("/mnt/Data");
        ServiceStorage.startupMounts = [{ source: "UUID=DATA", target: "/mnt/Existing" }];
        ServiceStorage.prepareMount();
        check(ServiceStorage.error === "service.storage.alreadyConfigured", "existing startup entry preserved");
        ServiceStorage.startupMounts = [];
        ServiceStorage.setMountMode("once");
        ServiceStorage.prepareMount();
        check(ServiceStorage.confirming && !ServiceStorage.busy, "prepare does not mount");
        ServiceStorage.cancelMount();
        ServiceStorage.confirmMount();
        check(!ServiceStorage.busy, "cancel never mounts");
        ServiceStorage.prepareMount();
        ServiceStorage.setMountMode("persistent");
        check(!ServiceStorage.confirming, "changing mode invalidates confirmation");
        ServiceStorage.setMountMode("once");
        ServiceStorage.prepareMount();
        phase = 1;
        ServiceStorage.confirmMount();
    }

    Component.onCompleted: Qt.callLater(() => ServiceStorage.refresh())

    Timer
    {
        interval: 25
        running: true
        repeat: true
        onTriggered:
        {
            if (ServiceStorage.busy || ServiceStorage.loading || !ServiceStorage.devicesLoaded || !ServiceStorage.volumesLoaded || ServiceStorage.udisksCommand === "") return;
            if (tests.phase === 0) { tests.begin(); return; }
            if (tests.phase === 1)
            {
                tests.check(ServiceStorage.selectedDevice.mounted, "mounted state refreshed after mount once");
                tests.check(tests.volumeDelegates === ServiceStorage.volumes.length, "refresh preserves existing volume delegates");
                tests.check(Math.abs(volumeRows.itemAt(0).share - 0.6) < 1e-9, "existing volume delegate receives updated usage roles");
                tests.check(ServiceStorage.message === "service.storage.mountedOnce", "mount once success reported");
                ServiceStorage.selectDevice("/dev/test-persistent");
                ServiceStorage.setMountMode("persistent");
                ServiceStorage.setMountPoint("/mnt/Persistent Data");
                ServiceStorage.prepareMount();
                tests.check(ServiceStorage.pending.target === "/mnt/Persistent Data", "persistent confirmation freezes target");
                tests.phase = 2;
                ServiceStorage.confirmMount();
                return;
            }
            if (tests.phase === 2)
            {
                tests.check(ServiceStorage.selectedDevice.mounted, "startup mount refreshed");
                tests.check(ServiceStorage.message === "service.storage.mountedPersistent", "startup mount success reported");
                ServiceStorage.selectDevice("/dev/test-fail");
                ServiceStorage.setMountMode("persistent");
                ServiceStorage.setMountPoint("/mnt/Denied");
                ServiceStorage.prepareMount();
                tests.phase = 3;
                ServiceStorage.confirmMount();
                return;
            }
            if (tests.phase === 3)
            {
                tests.check(ServiceStorage.error === "service.storage.authorizationCancelled", "cancelled authorization reported");
                tests.check(!ServiceStorage.selectedDevice.mounted, "failed mount never marks disk mounted");
                ServiceStorage.executeMount({ path: "/dev/test-fail", uuid: "CHANGED", filesystem: "ext4", mode: "once", target: "" });
                tests.check(ServiceStorage.error === "service.storage.deviceChanged", "changed device identity rejected before executing a mount");
                console.log("REGRESSIONS_PASSED storage");
                Qt.quit();
            }
        }
    }
    Timer { interval: 8000; running: true; onTriggered: { console.error("REGRESSION_FAILED storage timeout", ServiceStorage.error); Qt.quit(); } }
}
