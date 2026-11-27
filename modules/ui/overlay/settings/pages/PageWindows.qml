pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageWindows

    title: Tr.tr("settings.structure.windows")
    subtitle: Tr.tr("settings.windows.description")

    function update(key, value) { ServiceLayout.update(key, value) }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.layout")

        SettingsRow
        {
            label: Tr.tr("settings.windows.gaps")
            SettingsStepper
            {
                objectName: "windowGaps"
                value: Config.windowGaps
                from: 0; to: 64; step: 1; suffix: " px"
                onEdited: value => pageWindows.update("windowGaps", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.windows.centerFocused")
            description: Tr.tr("settings.windows.centerFocusedHint")
            Toggle
            {
                objectName: "windowCenterFocused"
                checked: Config.windowCenterFocused
                onToggled: value => pageWindows.update("windowCenterFocused", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.windows.centerSingle")
            description: Tr.tr("settings.windows.centerSingleHint")
            Toggle
            {
                objectName: "windowCenterSingle"
                checked: Config.windowCenterSingle
                onToggled: value => pageWindows.update("windowCenterSingle", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.windows.overviewSize")
            SettingsSlider
            {
                objectName: "windowOverviewSize"
                value: Config.windowOverviewSize
                from: 0.25; to: 1.5; step: 0.05
                valueText: shown.toFixed(2) + "×"
                onMoved: value => pageWindows.update("windowOverviewSize", value)
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.shape")

        SettingsRow
        {
            label: Tr.tr("settings.windows.cornerRadius")
            SettingsSlider
            {
                objectName: "windowRadius"
                value: Config.windowRadius
                from: 0; to: 20; step: 1
                valueText: Math.round(shown) + " px"
                onMoved: value => pageWindows.update("windowRadius", Math.round(value))
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.windows.clipContent")
            Toggle
            {
                objectName: "windowClipContent"
                checked: Config.windowClipContent
                onToggled: value => pageWindows.update("windowClipContent", value)
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.borders")

        SettingsRow
        {
            label: Tr.tr("settings.windows.border")
            SettingsChoices
            {
                objectName: "windowBorderMode"
                options: Registry.windowBorderOptions
                current: Config.windowBorderMode
                onSelected: value => pageWindows.update("windowBorderMode", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.windows.borderWidth")
            enabled: Config.windowBorderMode !== Enums.BorderOff
            SettingsSlider
            {
                objectName: "windowBorderWidth"
                value: Config.windowBorderWidth
                from: 1; to: 8; step: 1
                valueText: Math.round(shown) + " px"
                onMoved: value => pageWindows.update("windowBorderWidth", Math.round(value))
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.windows.borderColor")
            enabled: Config.windowBorderMode === Enums.BorderAll
            SettingsChoices
            {
                objectName: "windowBorderColor"
                options: Registry.windowColorOptions
                current: Config.windowBorderColor
                onSelected: value => pageWindows.update("windowBorderColor", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.windows.focusColor")
            enabled: Config.windowBorderMode !== Enums.BorderOff
            SettingsChoices
            {
                objectName: "windowFocusColor"
                options: Registry.windowColorOptions
                current: Config.windowFocusColor
                onSelected: value => pageWindows.update("windowFocusColor", value)
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.opacity")

        SettingsRow
        {
            label: Tr.tr("settings.windows.focusOpacity")
            SettingsSlider
            {
                objectName: "windowFocusOpacity"
                value: Config.windowFocusOpacity
                from: 0.5; to: 1; step: 0.01
                valueText: Math.round(shown * 100) + "%"
                onMoved: value => pageWindows.update("windowFocusOpacity", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.windows.unfocusedOpacity")
            SettingsSlider
            {
                objectName: "windowUnfocusedOpacity"
                value: Config.windowUnfocusedOpacity
                from: 0.5; to: 1; step: 0.01
                valueText: Math.round(shown * 100) + "%"
                onMoved: value => pageWindows.update("windowUnfocusedOpacity", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.windows.blurBehind")
            description: Tr.tr("settings.windows.blurBehindHint")
            Toggle
            {
                objectName: "windowBlurBehind"
                checked: Config.windowBlurBehind
                onToggled: value => pageWindows.update("windowBlurBehind", value)
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.movement")

        SettingsRow
        {
            label: Tr.tr("settings.windows.animate")
            Toggle
            {
                objectName: "windowAnimate"
                checked: Config.windowAnimate
                onToggled: value => pageWindows.update("windowAnimate", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("common.style")
            enabled: Config.windowAnimate
            SettingsChoices
            {
                objectName: "windowAnimationStyle"
                options: Registry.windowAnimationOptions
                current: Config.windowAnimationStyle
                onSelected: value => pageWindows.update("windowAnimationStyle", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.windows.animationSpeed")
            enabled: Config.windowAnimate && Config.windowAnimationStyle !== Enums.WindowInstant
            SettingsSlider
            {
                objectName: "windowAnimationSpeed"
                value: Config.windowAnimationSpeed
                from: 0.25; to: 2; step: 0.05
                valueText: shown.toFixed(2) + "×"
                onMoved: value => pageWindows.update("windowAnimationSpeed", value)
            }
        }
    }

    SettingsRowGroup
    {
        visible: !ServiceCompositor.supports("windows") || ServiceLayout.error !== ""
        title: Tr.tr("settings.windows.compositor")

        SettingsRow
        {
            label: ServiceLayout.error !== "" ? Tr.tr("settings.windows.applyFailed") : Tr.tr("settings.windows.unsupported")
            description: ServiceLayout.error !== ""
                ? ServiceLayout.error
                : Tr.tr("settings.windows.unsupportedHint")
            Button
            {
                visible: ServiceLayout.error !== ""
                text: Tr.tr("settings.windows.reapply")
                enabled: !ServiceLayout.busy && ServiceCompositor.supports("windows")
                onClicked: ServiceLayout.reapply()
            }
        }
    }
}
