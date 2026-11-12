pragma Singleton

import QtQuick
import Quickshell

import "../common"
import "../core"

Singleton
{
    id: keyboard

    property bool visible: false
    property string output: ""
    readonly property string error: native.error
    readonly property var engine: native.item
    readonly property bool busy: native.busy
    readonly property bool ready: engine !== null && engine.ready
    readonly property string status: busy ? Tr.tr("keyboard.loading") : error || (engine ? engine.error : "")
    readonly property var layouts: ServiceKeyboard.layouts.length ? ServiceKeyboard.layouts : [{layout: "us", variant: ""}]
    property int layoutIndex: 0

    function show(screenName = "")
    {
        if (!Config.virtualKeyboardEnabled || ServiceScreenshot.active) return;
        output = screenName || ServiceCompositor.focusedOutput;
        layoutIndex = Math.max(0, Math.min(layouts.length - 1, ServiceCompositor.keyboardLayoutIndex));
        visible = true;
        if (!engine) native.load();
        else connectEngine();
    }
    function hide()
    {
        visible = false;
        if (engine) { engine.reset(); engine.disconnectDisplay(); }
    }
    function toggle(screenName = "") { if (visible) hide(); else show(screenName); }
    function connectEngine()
    {
        if (!engine) return;
        engine.local = ServiceLock.locked;
        if (visible && !ServiceLock.locked) engine.connectDisplay();
    }
    function selectLayout(index)
    {
        layoutIndex = Math.max(0, Math.min(layouts.length - 1, index));
        // The virtual device owns its keymap; leave the physical keyboard layout alone.
    }
    onLayoutsChanged: layoutIndex = Math.max(0, Math.min(layoutIndex, layouts.length - 1))

    NativeLoader
    {
        id: native
        helper: "build-virtual-keyboard"
        failureText: Tr.tr("keyboard.unavailable")
        onLoaded: keyboard.connectEngine()
    }
    Connections { target: Config; function onVirtualKeyboardEnabledChanged() { if (!Config.virtualKeyboardEnabled) keyboard.hide(); } }
    Connections { target: ServiceLock; function onLockedChanged() { keyboard.hide(); keyboard.connectEngine(); } }
    Connections { target: ServiceScreenshot; function onActiveChanged() { if (ServiceScreenshot.active) keyboard.hide(); } }
}
