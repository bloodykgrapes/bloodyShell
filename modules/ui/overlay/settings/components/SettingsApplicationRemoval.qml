import QtQuick
import Quickshell
import Quickshell.Io

import "../../../../common"
import "../../../../core"
import "." as Parts

Parts.SettingsConfirmation
{
    id: removal

    property var application: null
    property var plan: null
    readonly property var helper: Paths.commandFor("applications")

    objectName: "applicationRemoval"
    title: Tr.tr("settings.applications.deleteTitle").arg(application ? application.name : "")
    description: command.busy ? Tr.tr("common.loading") : plan
        ? Tr.tr("settings.applications.deleteDescription").arg(plan.package).arg(plan.manager)
        : Tr.tr("settings.applications.deleteUnavailable")
    acceptText: Tr.tr("settings.applications.delete")
    acceptEnabled: plan !== null && !command.busy
    danger: true

    function request(app)
    {
        if (command.busy) return;
        application = app;
        plan = null;
        errorText = "";
        open();
        command.run(helper.concat(["removal", app.id]));
    }

    onAccepted:
    {
        if (!plan || command.busy) return;
        Quickshell.execDetached(plan.terminal.concat(helper, ["remove", application.id, plan.target]));
        close();
    }

    CommandProcess
    {
        id: command
        stdout: StdioCollector { id: result }
        onCompleted: code =>
        {
            if (code !== 0) removal.errorText = errorMessage(Tr.tr("settings.applications.deleteUnavailable"));
            else
            {
                try { removal.plan = JSON.parse(result.text); }
                catch (error) { removal.errorText = Tr.tr("settings.applications.deleteUnavailable"); }
            }
        }
    }
}
