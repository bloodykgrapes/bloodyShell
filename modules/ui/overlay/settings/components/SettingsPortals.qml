pragma ComponentBehavior: Bound

import QtQuick

import "../../../../core"
import "../../../../services"

SettingsRow
{
    id: portals
    objectName: "portalSettings"

    label: Tr.tr("settings.portals.dialogs")
    enabled: ServiceAppearance.loaded

    function backendLabel(value)
    {
        const names = new Map([["gtk", "GTK"], ["gnome", "GNOME"], ["gnome-keyring", "GNOME Keyring"], ["kde", "KDE"], ["lxqt", "LXQt"], ["cosmic", "COSMIC"], ["wlr", "wlroots"], ["hyprland", "Hyprland"], ["none", Tr.tr("common.none")], ["*", Tr.tr("common.default")]]);
        return value.split(";").map(name => names.get(name) || name).join(" → ");
    }

    function dialogOptions()
    {
        const available = ServiceAppearance.portalBackends.filter(backend => backend.interfaces.includes("FileChooser"));
        const result = [{ label: Tr.tr("common.default"), value: "" }]
            .concat(available.map(backend => ({ label: backendLabel(backend.id), value: backend.id })));
        const value = ServiceAppearance.portalValue("FileChooser");
        if (value && !available.some(backend => backend.id === value))
        {
            const supported = value.split(";").every(id => id === "none" || id === "*" || available.some(backend => backend.id === id));
            const label = backendLabel(value);
            result.push({ label: supported ? label : Tr.tr("settings.portals.unavailable").arg(label), value: value });
        }
        return result;
    }

    SettingsCombo
    {
        objectName: "portalSelector-FileChooser"
        options: portals.dialogOptions()
        current: ServiceAppearance.portalValue("FileChooser")
        onSelected: value => ServiceAppearance.setPortal("FileChooser", value)
    }
}
