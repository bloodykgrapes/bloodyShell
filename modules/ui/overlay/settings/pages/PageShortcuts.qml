pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    id: pageShortcuts

    title: Tr.tr("settings.shortcuts.title")
    subtitle: Tr.tr("settings.shortcuts.description")

    readonly property var windowBindings:
    [
        { action: Tr.tr("settings.shortcuts.nextWindow"), keys: "Alt+Tab" },
        { action: Tr.tr("settings.shortcuts.previousWindow"), keys: "Alt+Shift+Tab" },
        { action: Tr.tr("settings.shortcuts.closeWindow"), keys: "Mod+Q" },
        { action: Tr.tr("settings.shortcuts.overview"), keys: "Mod+Tab" },
        { action: Tr.tr("settings.shortcuts.tabbedColumn"), keys: "Mod+W" },
        { action: Tr.tr("settings.shortcuts.floating"), keys: "Mod+V" },
        { action: Tr.tr("settings.shortcuts.focusFloating"), keys: "Mod+Shift+V" },
        { action: Tr.tr("settings.shortcuts.centerColumn"), keys: "Mod+C" },
        { action: Tr.tr("settings.shortcuts.centerColumns"), keys: "Mod+Ctrl+C" },
        { action: Tr.tr("settings.shortcuts.maximizeWindow"), keys: "Mod+M" },
        { action: Tr.tr("settings.shortcuts.maximizeColumn"), keys: "Mod+F" },
        { action: Tr.tr("settings.shortcuts.expandColumn"), keys: "Mod+Ctrl+F" },
        { action: Tr.tr("settings.shortcuts.fullscreen"), keys: "Mod+Shift+F" },
        { action: Tr.tr("settings.shortcuts.nextWidth"), keys: "Mod+R" },
        { action: Tr.tr("settings.shortcuts.previousWidth"), keys: "Mod+Ctrl+R" },
        { action: Tr.tr("settings.shortcuts.nextHeight"), keys: "Mod+Shift+R" },
        { action: Tr.tr("settings.shortcuts.resetHeight"), keys: "Mod+Shift+Ctrl+R" },
        { action: Tr.tr("settings.shortcuts.columnWidth"), keys: "Mod+Ctrl+Minus/Equal" },
        { action: Tr.tr("settings.shortcuts.windowHeight"), keys: "Mod+Shift+Minus/Equal" },
        { action: Tr.tr("settings.shortcuts.focusWindow"), keys: "Mod+Up/Down" },
        { action: Tr.tr("settings.shortcuts.focusColumn"), keys: "Mod+Left/Right" },
        { action: Tr.tr("settings.shortcuts.moveWindow"), keys: "Mod+Shift+Up/Down" },
        { action: Tr.tr("settings.shortcuts.moveColumn"), keys: "Mod+Shift+Left/Right" },
        { action: Tr.tr("settings.shortcuts.focusMonitor"), keys: "Mod+Ctrl+Up/Down/Left/Right" },
        { action: Tr.tr("settings.shortcuts.moveToMonitor"), keys: "Mod+Shift+Ctrl+Up/Down/Left/Right" },
        { action: Tr.tr("settings.shortcuts.focusWorkspace"), keys: "Mod+1–9" },
        { action: Tr.tr("settings.shortcuts.moveToWorkspace"), keys: "Mod+Shift+1–9" },
        { action: Tr.tr("settings.shortcuts.adjacentWorkspace"), keys: "Mod+Page_Up/Page_Down" },
        { action: Tr.tr("settings.shortcuts.moveToAdjacentWorkspace"), keys: "Mod+Ctrl+Page_Up/Page_Down" },
        { action: Tr.tr("settings.shortcuts.reorderWorkspace"), keys: "Mod+Shift+Page_Up/Page_Down" },
        { action: Tr.tr("settings.shortcuts.adjacentWorkspace"), keys: "Mod+WheelScrollUp/WheelScrollDown" },
        { action: Tr.tr("settings.shortcuts.focusColumn"), keys: "Mod+WheelScrollLeft/WheelScrollRight" },
        { action: Tr.tr("settings.shortcuts.moveToAdjacentWorkspace"), keys: "Mod+Shift+WheelScrollUp/WheelScrollDown" },
        { action: Tr.tr("settings.shortcuts.moveColumn"), keys: "Mod+Shift+WheelScrollLeft/WheelScrollRight" },
        { action: Tr.tr("settings.shortcuts.moveToAdjacentWorkspace"), keys: "Mod+Shift+TouchpadScrollUp/TouchpadScrollDown" },
        { action: Tr.tr("settings.shortcuts.moveColumn"), keys: "Mod+Shift+TouchpadScrollLeft/TouchpadScrollRight" },
        { action: Tr.tr("settings.shortcuts.consumeOrExpel"), keys: "Mod+BracketLeft/BracketRight" },
        { action: Tr.tr("settings.shortcuts.consumeWindow"), keys: "Mod+Comma" },
        { action: Tr.tr("settings.shortcuts.expelWindow"), keys: "Mod+Period" }
    ]
    readonly property var overlayBindings:
    [
        { action: Tr.tr("common.launcher"), keys: "Mod+D" },
        { action: Tr.tr("common.settings"), keys: "Mod+I" },
        { action: Tr.tr("common.wallpapers"), keys: "Mod+Y" },
        { action: Tr.tr("settings.shortcuts.powerMenu"), keys: "Mod+P" },
        { action: Tr.tr("settings.shortcuts.screenshot"), keys: "Print" },
        { action: Tr.tr("settings.shortcuts.screenScreenshot"), keys: "Ctrl+Print" }
    ]
    readonly property var shellBindings:
    [
        { action: Tr.tr("settings.shortcuts.lock"), keys: "Mod+L" },
        { action: Tr.tr("settings.shortcuts.terminal"), keys: "Mod+T" },
        { action: Tr.tr("settings.shortcuts.files"), keys: "Mod+E" },
        { action: Tr.tr("settings.shortcuts.systemMonitor"), keys: "Mod+B" },
        { action: Tr.tr("settings.shortcuts.volume"), keys: "XF86AudioRaiseVolume/XF86AudioLowerVolume" },
        { action: Tr.tr("settings.shortcuts.touchpadVolume"), keys: "Mod+TouchpadScrollUp/TouchpadScrollDown" },
        { action: Tr.tr("settings.shortcuts.mute"), keys: "XF86AudioMute" },
        { action: Tr.tr("settings.shortcuts.microphoneMute"), keys: "XF86AudioMicMute" },
        { action: Tr.tr("settings.shortcuts.playPause"), keys: "XF86AudioPlay" },
        { action: Tr.tr("settings.shortcuts.stopMedia"), keys: "XF86AudioStop" },
        { action: Tr.tr("settings.shortcuts.previousTrack"), keys: "XF86AudioPrev" },
        { action: Tr.tr("settings.shortcuts.nextTrack"), keys: "XF86AudioNext" },
        { action: Tr.tr("settings.shortcuts.brightness"), keys: "XF86MonBrightnessUp/XF86MonBrightnessDown" },
        { action: Tr.tr("settings.shortcuts.screenReader"), keys: "Super+Alt+S" },
        { action: Tr.tr("settings.shortcuts.inhibit"), keys: "Mod+Escape" },
        { action: Tr.tr("settings.shortcuts.quit"), keys: "Ctrl+Alt+Delete" }
    ]

    function formatKeys(shortcut)
    {
        const names = {
            Mod: "Super", Up: "↑", Down: "↓", Left: "←", Right: "→",
            Minus: "−", Equal: "=", Comma: ",", Period: ".", BracketLeft: "[", BracketRight: "]",
            Page_Up: "PgUp", Page_Down: "PgDn", Escape: "Esc",
            WheelScrollUp: Tr.tr("settings.shortcuts.wheel") + " ↑",
            WheelScrollDown: Tr.tr("settings.shortcuts.wheel") + " ↓",
            WheelScrollLeft: Tr.tr("settings.shortcuts.wheel") + " ←",
            WheelScrollRight: Tr.tr("settings.shortcuts.wheel") + " →",
            TouchpadScrollUp: Tr.tr("settings.shortcuts.touchpad") + " ↑",
            TouchpadScrollDown: Tr.tr("settings.shortcuts.touchpad") + " ↓",
            TouchpadScrollLeft: Tr.tr("settings.shortcuts.touchpad") + " ←",
            TouchpadScrollRight: Tr.tr("settings.shortcuts.touchpad") + " →",
            XF86AudioRaiseVolume: Tr.tr("common.volume") + " ↑",
            XF86AudioLowerVolume: Tr.tr("common.volume") + " ↓",
            XF86AudioMute: Tr.tr("settings.shortcuts.muteKey"),
            XF86AudioMicMute: Tr.tr("settings.shortcuts.microphoneKey"),
            XF86AudioPlay: Tr.tr("settings.shortcuts.playKey"),
            XF86AudioStop: Tr.tr("settings.shortcuts.stopKey"),
            XF86AudioPrev: Tr.tr("settings.shortcuts.previousKey"),
            XF86AudioNext: Tr.tr("settings.shortcuts.nextKey"),
            XF86MonBrightnessUp: Tr.tr("sidebar.brightness") + " ↑",
            XF86MonBrightnessDown: Tr.tr("sidebar.brightness") + " ↓"
        };
        return shortcut.split("+").map(part => part.split("/").map(key => names[key] || key).join(" / ")).join(" + ");
    }

    SettingsGroup
    {
        objectName: "windowShortcuts"
        title: Tr.tr("settings.shortcuts.windowManagement")
        Repeater
        {
            model: pageShortcuts.windowBindings
            ShortcutRow
            {
                required property var modelData
                label: modelData.action
                shortcut: pageShortcuts.formatKeys(modelData.keys)
            }
        }
    }
    SettingsGroup
    {
        objectName: "overlayShortcuts"
        title: Tr.tr("settings.shortcuts.overlays")
        Repeater
        {
            model: pageShortcuts.overlayBindings
            ShortcutRow
            {
                required property var modelData
                label: modelData.action
                shortcut: pageShortcuts.formatKeys(modelData.keys)
            }
        }
    }
    SettingsGroup
    {
        objectName: "shellShortcuts"
        title: Tr.tr("settings.shortcuts.shellActions")
        Repeater
        {
            model: pageShortcuts.shellBindings
            ShortcutRow
            {
                required property var modelData
                label: modelData.action
                shortcut: pageShortcuts.formatKeys(modelData.keys)
            }
        }
    }

    component ShortcutRow: SettingsRow
    {
        id: row
        property string shortcut: ""
        stacked: actionMetrics.advanceWidth + keyMetrics.advanceWidth + 76 > width
        Accessible.role: Accessible.StaticText
        Accessible.name: label + ": " + shortcut

        TextMetrics { id: actionMetrics; text: row.label; font.family: Theme.fontText; font.pixelSize: Math.round(13 * Config.themeScale) }
        TextMetrics { id: keyMetrics; text: row.shortcut; font: keys.font }
        Rectangle
        {
            implicitWidth: keyMetrics.advanceWidth + 20
            width: Math.min(implicitWidth, row.stacked ? parent.width : row.width * 0.55)
            height: Math.max(28, keys.implicitHeight + 12)
            radius: Theme.radiusMedium
            color: Theme.colorField
            ShellText
            {
                id: keys
                x: 10; y: 6
                width: parent.width - 20
                label: row.shortcut
                size: 11
                font.family: Theme.fontMono
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
