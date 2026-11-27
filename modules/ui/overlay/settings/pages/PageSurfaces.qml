pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageSurfaces

    title: Tr.tr("settings.structure.surfaces")
    subtitle: Tr.tr("settings.surfaces.description")
    property int rememberedWidth: Math.max(6, Config.frameThickness)

    header: SettingsShellPreview { pageHeight: pageSurfaces.height; showMaterialSample: true }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.material")

        SettingsRow
        {
            label: Tr.tr("settings.structure.background")
            SettingsChoices
            {
                objectName: "shellSurfaceSelector"
                options: Registry.surfaceOptions
                current: Config.shellSurface
                onSelected: value => Config.set("shellSurface", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.surfaces.blurStrength")
            description: Tr.tr("settings.surfaces.blurStrengthHint")
            enabled: Config.shellSurface === Enums.SurfaceBlur

            SettingsSlider
            {
                objectName: "surfaceBlurStrength"
                value: Config.surfaceBlurStrength
                from: 0
                to: 100
                step: 1
                onMoved: value => Config.set("surfaceBlurStrength", Math.round(value))
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.surfaces.blurGrain")
            enabled: Config.shellSurface === Enums.SurfaceBlur

            SettingsSlider
            {
                objectName: "surfaceBlurGrain"
                value: Config.surfaceBlurGrain
                from: 0
                to: 100
                step: 1
                onMoved: value => Config.set("surfaceBlurGrain", Math.round(value))
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.frame")

        SettingsRow
        {
            label: Tr.tr("common.enabled")
            Toggle
            {
                checked: Config.frameThickness > 0
                onToggled: value =>
                {
                    if (!value) pageSurfaces.rememberedWidth = Math.max(2, Config.frameThickness);
                    Config.set("frameThickness", value ? pageSurfaces.rememberedWidth : 0);
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.structure.width")
            enabled: Config.frameThickness > 0
            SettingsStepper
            {
                value: Config.frameThickness || pageSurfaces.rememberedWidth
                from: 2; to: 8; step: 1; suffix: " px"
                onEdited: value => Config.set("frameThickness", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.surfaces.frameRadius")
            enabled: Config.frameThickness > 0

            SettingsSlider
            {
                objectName: "frameRadius"
                value: Config.frameRadius
                from: 0
                to: 30
                step: 1
                valueText: Math.round(shown) + " px"
                onMoved: value => Config.set("frameRadius", Math.round(value))
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.surfaces.menus")

        SettingsRow
        {
            label: Tr.tr("settings.surfaces.menuRadius")

            SettingsSlider
            {
                objectName: "menuRadius"
                value: Config.menuRadius
                from: 0
                to: 30
                step: 1
                valueText: Math.round(shown) + " px"
                onMoved: value => Config.set("menuRadius", Math.round(value))
            }
        }
    }
}
