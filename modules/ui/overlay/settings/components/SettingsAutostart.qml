pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls

import "../../../../common"
import "../../../../core"
import "../../../../services"

SettingsDisclosure
{
    id: autostart

    title: Tr.tr("settings.autostart.title")
    description: Tr.tr("settings.autostart.description")
    icon: Icon.computerReboot
    summary: String(ServiceApplications.autostartEntries.length)

    readonly property alias picker: appPicker
    property string pendingApp: ""
    property string query: ""
    readonly property var candidates: ServiceApplications.search(query).filter(app => !ServiceApplications.hasAutostart(app.id))

    function stateText(entry)
    {
        const label = Tr.tr(entry.enabled ? "settings.autostart.enabled" : "settings.autostart.disabled");
        const reasons = {
            invalid: "settings.autostart.invalid",
            desktop: "settings.autostart.otherDesktop",
            executable: "settings.autostart.missingExecutable",
            session: "settings.autostart.excluded"
        };
        return reasons[entry.reason] ? label + " · " + Tr.tr(reasons[entry.reason]) : label;
    }

    SettingsRow
    {
        label: Tr.tr("settings.autostart.atLogin")
        description: Tr.tr("settings.autostart.changesHint")

        Row
        {
            spacing: 6
            SettingsButton
            {
                id: addButton
                objectName: "autostartAdd"
                text: Tr.tr("settings.autostart.addApplication")
                icon: Icon.add
                enabled: !ServiceApplications.autostartBusy
                onClicked: appPicker.open()
            }
            SettingsIconButton
            {
                icon: Icon.reload
                enabled: !ServiceApplications.autostartBusy
                onClicked: ServiceApplications.refreshAutostart()
                Accessible.name: Tr.tr("settings.autostart.refresh")
            }
        }
    }

    function choose(appId)
    {
        appPicker.errorText = "";
        if (ServiceApplications.addAutostart(appId)) pendingApp = appId;
    }
    function finishAdd()
    {
        if (pendingApp === "" || ServiceApplications.autostartBusy) return;
        if (ServiceApplications.hasAutostart(pendingApp)) appPicker.close();
        else appPicker.errorText = ServiceApplications.autostartError || Tr.tr("settings.autostart.failed");
        pendingApp = "";
    }
    Connections
    {
        target: ServiceApplications
        function onAutostartBusyChanged() { if (!ServiceApplications.autostartBusy) Qt.callLater(autostart.finishAdd); }
    }
    RenderActivity
    {
        id: activity
        target: autostart
        onActiveChanged: if (!active) appPicker.close()
    }
    onExpandedChanged: if (!expanded) appPicker.close()

    SettingsPopup
    {
        id: appPicker
        objectName: "autostartPicker"
        property string errorText: ""
        host: autostart
        width: Math.min(560, Math.max(0, parent.width - 32))
        height: Math.min(540, Math.max(0, parent.height - 32))
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        onAboutToShow:
        {
            autostart.query = "";
            search.text = "";
            errorText = "";
            results.contentY = 0;
            results.currentIndex = -1;
        }
        onOpened: search.grabFocus()
        onClosed:
        {
            autostart.pendingApp = "";
            if (!appPicker.suspended && activity.active && addButton.enabled) addButton.forceActiveFocus(Qt.PopupFocusReason);
        }
        contentItem: Column
        {
            id: pickerBody
            spacing: 14
            Accessible.role: Accessible.Dialog
            Accessible.name: Tr.tr("settings.autostart.addApplication")

            ShellText
            {
                id: pickerTitle
                width: parent.width
                label: Tr.tr("settings.autostart.addApplication")
                size: 18
                font.bold: true
                wrapMode: Text.Wrap
            }
            SettingsInput
            {
                id: search
                objectName: "autostartSearch"
                width: parent.width
                placeholderText: Tr.tr("settings.applications.searchPlaceholder")
                onTextEdited: value => { autostart.query = value; results.contentY = 0; results.currentIndex = -1; }
                onAccepted:
                {
                    if (autostart.candidates.length === 1 && !ServiceApplications.autostartBusy) autostart.choose(autostart.candidates[0].id);
                    else if (results.count > 0) { results.currentIndex = 0; results.forceActiveFocus(); }
                }
                Keys.onDownPressed: if (results.count > 0) { results.currentIndex = 0; results.forceActiveFocus(); }
            }
            ShellText
            {
                id: failure
                width: parent.width
                visible: appPicker.errorText !== ""
                label: appPicker.errorText
                color: Theme.colorCritical
                wrapMode: Text.Wrap
            }
            Item
            {
                width: parent.width
                height: Math.max(0, appPicker.availableHeight - pickerTitle.height - search.height - cancel.height
                    - pickerBody.spacing * 3 - (failure.visible ? failure.height + pickerBody.spacing : 0))
                ListView
                {
                    id: results
                    objectName: "autostartCandidates"
                    anchors.fill: parent
                    model: appPicker.visible ? autostart.candidates : []
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: -1
                    keyNavigationEnabled: true
                    highlight: null
                    SmoothScroll { view: results }
                    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
                    Keys.onReturnPressed: if (currentIndex >= 0 && !ServiceApplications.autostartBusy) autostart.choose(autostart.candidates[currentIndex].id)
                    Keys.onEnterPressed: if (currentIndex >= 0 && !ServiceApplications.autostartBusy) autostart.choose(autostart.candidates[currentIndex].id)
                    delegate: SettingsRow
                    {
                        id: candidate
                        required property var modelData
                        width: results.width - 12
                        highlighted: results.activeFocus && ListView.isCurrentItem
                        icon: ServiceApplications.iconFor(modelData.id)
                        label: modelData.name
                        description: modelData.id
                        SettingsButton
                        {
                            objectName: "autostartChoose-" + candidate.modelData.id
                            text: Tr.tr("common.add")
                            icon: Icon.add
                            enabled: !ServiceApplications.autostartBusy
                            onClicked: autostart.choose(candidate.modelData.id)
                        }
                    }
                }
                ShellText
                {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: results.count === 0
                    label: Tr.tr("settings.applications.noMatches")
                    color: Theme.text2
                    wrapMode: Text.Wrap
                }
            }
            SettingsButton
            {
                id: cancel
                objectName: "autostartCancel"
                anchors.right: parent.right
                text: Tr.tr("common.cancel")
                onClicked: appPicker.close()
            }
        }
    }

    SettingsRow
    {
        visible: ServiceApplications.autostartError !== ""
        label: Tr.tr("common.error")
        description: ServiceApplications.autostartError
    }
    SettingsRow
    {
        visible: ServiceApplications.autostartSession === "inactive" || ServiceApplications.autostartSession === "unavailable"
        label: Tr.tr("settings.autostart.sessionUnavailable")
        description: Tr.tr("settings.autostart.sessionHint")
    }
    Repeater
    {
        model: ServiceApplications.autostartEntries

        SettingsRow
        {
            id: entry
            required property var modelData
            icon: ServiceApplications.iconSource(modelData.icon)
            label: modelData.name
            description: autostart.stateText(modelData)
            badge: modelData.system ? Tr.tr("settings.autostart.system") : ""

            Row
            {
                spacing: 10
                height: 32
                SettingsButton
                {
                    objectName: "autostartRemove-" + entry.modelData.id
                    visible: entry.modelData.removable
                    text: Tr.tr("common.remove")
                    icon: Icon.close
                    enabled: !ServiceApplications.autostartBusy
                    onClicked: ServiceApplications.removeAutostart(entry.modelData.id)
                }
                Toggle
                {
                    objectName: "autostartToggle-" + entry.modelData.id
                    anchors.verticalCenter: parent.verticalCenter
                    checked: entry.modelData.enabled
                    enabled: entry.modelData.valid && !ServiceApplications.autostartBusy
                    onToggled: value => ServiceApplications.setAutostartEnabled(entry.modelData.id, value)
                    Accessible.name: entry.modelData.name
                }
            }
        }
    }
    SettingsRow
    {
        visible: ServiceApplications.autostartEntries.length === 0 && !ServiceApplications.autostartBusy
        label: Tr.tr("settings.autostart.empty")
    }
}
