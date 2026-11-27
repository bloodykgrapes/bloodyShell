pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

import "../../../../common"
import "../../../../core"

SettingsRowGroup
{
    id: associations
    objectName: "fileAssociationsSection"

    property var entries: []
    property string error: ""
    readonly property bool busy: command.busy
    readonly property var helper: Paths.commandFor("applications").concat(["associations"])

    function refresh()
    {
        if (busy) return;
        error = "";
        command.run(helper.concat(["status"]));
    }
    Component.onCompleted: refresh()

    function select(entry, appId)
    {
        if (busy) return;
        error = "";
        command.run(helper.concat(["set", entry.id, appId]));
    }

    Column
    {
        width: parent.width
        spacing: 1
        Repeater
        {
            model: associations.entries.filter(entry => entry.group === "")
            SettingsFileAssociationRow
            {
                required property var modelData
                entry: modelData
                busy: associations.busy
                onSelected: appId => associations.select(entry, appId)
            }
        }
    }
    Repeater
    {
        model: ["images", "documents", "audio", "video"]
        SettingsRowGroup
        {
            id: category
            required property string modelData
            readonly property var entries: associations.entries.filter(entry => entry.group === modelData)
            objectName: "fileAssociationGroup-" + modelData
            title: Tr.tr("settings.fileAssociations." + modelData)
            Repeater
            {
                model: category.entries
                SettingsFileAssociationRow
                {
                    required property var modelData
                    entry: modelData
                    busy: associations.busy
                    onSelected: appId => associations.select(entry, appId)
                }
            }
        }
    }
    SettingsRow
    {
        visible: associations.error !== ""
        label: Tr.tr("common.actionFailed")
        description: associations.error
        Button { text: Tr.tr("common.refresh"); enabled: !associations.busy; onClicked: associations.refresh() }
    }
    CommandProcess
    {
        id: command
        stdout: StdioCollector { id: result }
        onCompleted: code =>
        {
            if (code !== 0) { associations.error = errorMessage(Tr.tr("settings.fileAssociations.failed")); return; }
            try { associations.entries = JSON.parse(result.text).entries; }
            catch (error) { associations.error = String(error); }
        }
    }
}
