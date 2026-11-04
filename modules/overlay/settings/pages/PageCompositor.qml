import QtQuick

import "../../../components/settings"
import "../../../core"
import "../../../services"

SettingsPage
{
    id: pageCompositor

    title: Tr.tr("settings.about.compositor")
    subtitle: Tr.tr("settings.compositor.howDrawsAndArrangesHint").arg("niri")

    Component.onCompleted: ServiceCompositor.refresh()

    SettingsGroup
    {
        visible: ServiceCompositor.error !== ""
        title: Tr.tr("settings.compositor.compositorSettings")

        SettingsRow
        {
            label: Tr.tr("settings.display.couldNotSave")
            badge: Tr.tr("common.error")
            badgeColor: Theme.colorCritical
            description: ServiceCompositor.error
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.compositor.windows")
        enabled: ServiceCompositor.loaded

        SettingsRow
        {
            label: Tr.tr("settings.compositor.focusRing")
            description: Tr.tr("settings.compositor.anOutlineInTheHint")
            SettingsSwitch { checked: ServiceCompositor.focusRing; onToggled: value => ServiceCompositor.setFocusRing(value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.compositor.focusRingWidth")
            enabled: ServiceCompositor.focusRing

            SettingsStepper
            {
                value: ServiceCompositor.focusRingWidth
                from: 1; to: 8; step: 1; suffix: " px"
                onEdited: value => ServiceCompositor.setFocusRingWidth(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.compositor.dimInactiveWindows")
            description: Tr.tr("settings.compositor.windowsWithoutFocusBecomeHint")
            SettingsSwitch { checked: ServiceCompositor.dimInactive; onToggled: value => ServiceCompositor.setDimInactive(value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.compositor.inactiveWindowOpacity")
            enabled: ServiceCompositor.dimInactive

            SettingsChoices
            {
                options: [{ label: "95%", value: 0.95 }, { label: "90%", value: 0.9 }, { label: "80%", value: 0.8 }, { label: "70%", value: 0.7 }]
                current: ServiceCompositor.dimOpacity
                onSelected: value => ServiceCompositor.setDimOpacity(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.compositor.cornerRadius")
            description: Tr.tr("settings.compositor.roundedCornersOfEveryWindow")

            SettingsStepper
            {
                value: ServiceCompositor.cornerRadius
                from: 0; to: 24; step: 2; suffix: " px"
                onEdited: value => ServiceCompositor.setCornerRadius(value)
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.compositor.layout")
        enabled: ServiceCompositor.loaded

        SettingsRow
        {
            label: Tr.tr("settings.compositor.gaps")
            description: Tr.tr("settings.compositor.spaceBetweenWindowsAnd")

            SettingsStepper
            {
                value: ServiceCompositor.gaps
                from: 0; to: 48; step: 2; suffix: " px"
                onEdited: value => ServiceCompositor.setGaps(value)
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.compositor.behaviour")
        enabled: ServiceCompositor.loaded

        SettingsRow
        {
            label: Tr.tr("settings.compositor.focusFollowsMouse")
            description: Tr.tr("settings.compositor.theWindowUnderThe")
            SettingsSwitch { checked: ServiceCompositor.focusFollowsMouse; onToggled: value => ServiceCompositor.setFocusFollowsMouse(value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.compositor.windowAnimations")
            description: Tr.tr("settings.compositor.openingClosingAndMovingHint")
            SettingsSwitch { checked: ServiceCompositor.animations; onToggled: value => ServiceCompositor.setAnimations(value) }
        }
    }
}
