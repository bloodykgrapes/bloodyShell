pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    title: Tr.tr("settings.structure.screenCapture")

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.snip")

        SettingsRow
        {
            label: Tr.tr("settings.structure.captureArea")
            SettingsChoices
            {
                options: [{label: Tr.tr("screenshot.area"), value: Enums.ScreenshotArea},
                    {label: Tr.tr("screenshot.screen"), value: Enums.ScreenshotScreen}]
                current: Config.screenshotMode
                onSelected: value => Config.set("screenshotMode", value)
            }
        }
    }

    SettingsRowGroup
    {
        objectName: "screenshotOptions"
        title: Tr.tr("settings.components.screenshots")

        SettingsRow
        {
            label: Tr.tr("settings.components.savePath")
            SettingsInput
            {
                objectName: "screenshotsPath"
                text: Config.screenshotsPath || Config.screenshotsDefault()
                onEditingFinished:
                {
                    Config.set("screenshotsPath", text.trim() || Config.screenshotsDefault());
                    text = Config.screenshotsPath;
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.components.fileName")
            description: Tr.tr("settings.components.fileNameHint")
            SettingsInput
            {
                objectName: "screenshotsFileName"
                text: Config.screenshotsFileName
                onEditingFinished:
                {
                    Config.set("screenshotsFileName", text.trim() || "%Y-%m-%d_%H.%M.%S");
                    text = Config.screenshotsFileName;
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.components.action")
            SettingsChoices
            {
                objectName: "screenshotsAction"
                options: [{label: Tr.tr("screenshot.copy"), value: "copy"}, {label: Tr.tr("screenshot.save"), value: "save"}]
                current: Config.screenshotsAction
                onSelected: value => Config.set("screenshotsAction", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.components.instantly")
            description: Tr.tr("settings.components.instantlyHint")
            Toggle
            {
                objectName: "screenshotsInstantly"
                checked: Config.screenshotsInstantly
                onToggled: value => Config.set("screenshotsInstantly", value)
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.recording")

        SettingsRow
        {
            label: Tr.tr("settings.components.savePath")
            SettingsInput
            {
                objectName: "recordingsPath"
                text: Config.recordingsPath || Config.recordingsDefault()
                onEditingFinished:
                {
                    Config.set("recordingsPath", text.trim() || Config.recordingsDefault());
                    text = Config.recordingsPath;
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.components.fileName")
            description: Tr.tr("settings.components.fileNameHint")
            SettingsInput
            {
                objectName: "recordingsFileName"
                text: Config.recordingsFileName
                onEditingFinished:
                {
                    Config.set("recordingsFileName", text.trim() || "%Y-%m-%d_%H.%M.%S");
                    text = Config.recordingsFileName;
                }
            }
        }
        SettingsRow
        {
            visible: ServiceRecording.active
            label: Tr.tr("recording.active")
            valueText: ServiceRecording.detail
        }
    }
}
