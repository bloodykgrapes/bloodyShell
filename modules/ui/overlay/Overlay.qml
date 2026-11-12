pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland

import "../../animations"
import "../../core"
import "../../services"
import "altTab"
import "polkit"
import "screenshot"

PanelWindow
{
    id: overlay

    property string output: ""
    property Item screenshotFocus: null
    readonly property var preparationOrder: ["launcher", "settings", "power", "wallpapers", "helper", "desktopMenu"]
    property var preparedComponents: []
    readonly property bool authenticating: authAgent.isActive
    readonly property bool switching: ServiceAltTab.active
    readonly property bool modal: authenticating || ServiceScreenshot.active || switching || OverlayState.active
    readonly property bool shown: !ServiceLock.locked && (modal || contentReveal > 0.001 || altTabReveal > 0.001 || polkitReveal > 0.001)

    property real contentReveal: OverlayState.active ? 1 : 0
    Ease on contentReveal
    {
        duration: OverlayState.active ? Theme.animationDurationOpen : Theme.animationDurationClose
        curve: OverlayState.active ? Theme.easingEmphasized : Theme.easingAccelerate
    }
    property real altTabReveal: ServiceAltTab.presented ? 1 : 0
    Ease on altTabReveal
    {
        duration: ServiceAltTab.presented ? Theme.animationDurationOpen : Theme.animationDurationClose
    }
    property real polkitReveal: authenticating ? 1 : 0
    Ease on polkitReveal
    {
        duration: overlay.authenticating ? Theme.animationDurationOpen : Theme.animationDurationClose
    }

    function activeFor(name)
    {
        if (name === "polkit") return authenticating;
        return OverlayState.current === name && !authenticating && !switching && !ServiceScreenshot.active;
    }
    function revealFor(name) { return name === "polkit" ? polkitReveal : contentReveal }
    function dismiss(name)
    {
        if (authenticating)
        {
            if (authAgent.flow) authAgent.flow.cancelAuthenticationRequest();
        }
        else if (ServiceScreenshot.busy) ServiceScreenshot.cancel();
        else if (switching) ServiceAltTab.cancel();
        else OverlayState.hide(name || OverlayState.current);
    }
    function holdOutput()
    {
        output = ServiceAltTab.active ? ServiceAltTab.output : OverlayState.screenName || ServiceCompositor.focusedOutput;
    }
    function loadContent()
    {
        const source = Registry.overlaySources[OverlayState.mounted];
        if (source) page.setSource(source, { host: overlay });
        else page.source = "";
    }
    function prepareNext()
    {
        const previous = preparedComponents[preparedComponents.length - 1];
        if (previous && previous.status === Component.Loading) return;
        const name = preparationOrder[preparedComponents.length];
        const source = Registry.overlaySources[name];
        if (!source) return;
        preparedComponents = preparedComponents.concat([Qt.createComponent(source, Component.Asynchronous)]);
    }

    Timer
    {
        interval: 250
        repeat: true
        running: Config.initialized && !overlay.modal && !ServiceLock.locked && overlay.preparedComponents.length < overlay.preparationOrder.length
        onTriggered: overlay.prepareNext()
    }
    function takeScreenshot(mode = -1)
    {
        ServiceScreenshot.start(overlay.shown && overlay.screen ? overlay.screen.name : "", mode);
    }

    screen: Quickshell.screens.find(s => s.name === (ServiceScreenshot.active ? ServiceScreenshot.output : modal || contentReveal > 0.001 || altTabReveal > 0.001 || polkitReveal > 0.001 ? output : ServiceCompositor.focusedOutput)) || Quickshell.screens[0] || null
    visible: shown
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    mask: authenticating || ServiceScreenshot.active || OverlayState.active ? null : switching ? switcherInput : transientInput

    WlrLayershell.namespace: "bloodyShell:overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: modal ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Region { id: transientInput }
    Region { id: switcherInput; regions: switcher.item && ServiceAltTab.presented ? [switcher.item.inputRegion] : [] }

    PolkitAgent { id: authAgent }
    Binding { target: OverlayState; property: "inhibited"; value: overlay.authenticating || ServiceLock.locked || ServiceScreenshot.active }
    Binding { target: OverlayState; property: "popupsSuspended"; value: overlay.authenticating || ServiceLock.locked || ServiceScreenshot.active || overlay.switching }
    Item
    {
        id: popupGuard
        readonly property Item controlsLayer: Controls.Overlay.overlay
        Binding
        {
            target: popupGuard.controlsLayer
            property: "visible"
            when: OverlayState.popupsSuspended && popupGuard.controlsLayer !== null
            value: false
            restoreMode: Binding.RestoreBindingOrValue
        }
    }
    AltTabKeyboard { }
    ShortcutInhibitor { window: overlay; enabled: overlay.switching || overlay.authenticating || OverlayState.active || ServiceScreenshot.active }

    IpcHandler
    {
        target: "screenshot"
        function show(): void { overlay.takeScreenshot() }
        function screen(): void { overlay.takeScreenshot(Enums.ScreenshotScreen) }
        function hide(): void { ServiceScreenshot.cancel() }
    }
    Shortcut
    {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: ServiceScreenshot.phase === "capturing"
        onActivated: ServiceScreenshot.cancel()
    }
    Connections
    {
        target: ServiceScreenshot
        function onPhaseChanged()
        {
            if (ServiceScreenshot.phase === "capturing")
            {
                const window = overlay.contentItem.Window.window;
                overlay.screenshotFocus = window ? window.activeFocusItem : null;
            }
        }
        function onActiveChanged()
        {
            if (ServiceScreenshot.active) return;
            Qt.callLater(() =>
            {
                if (overlay.authenticating || ServiceLock.locked || ServiceScreenshot.busy) return;
                if (overlay.screenshotFocus && overlay.screenshotFocus.visible) overlay.screenshotFocus.forceActiveFocus();
                else if (page.item && OverlayState.active) (page.item as Item).forceActiveFocus();
                overlay.screenshotFocus = null;
            });
        }
    }

    Connections
    {
        target: OverlayState
        function onMountedChanged() { overlay.loadContent() }
        function onCurrentChanged()
        {
            if (OverlayState.active && !overlay.authenticating && !overlay.switching)
            {
                overlay.holdOutput();
            }
        }
    }
    Connections
    {
        target: ServiceAltTab
        function onActiveChanged() { if (ServiceAltTab.active) overlay.holdOutput() }
    }
    Connections
    {
        target: authAgent
        function onIsActiveChanged()
        {
            if (authAgent.isActive)
            {
                ServiceScreenshot.cancel();
                if (!OverlayState.active) overlay.holdOutput();
                MenuState.close();
                ServiceAltTab.cancel();
            }
            else Qt.callLater(() =>
            {
                const view = page.item as Item;
                if (view) view.forceActiveFocus();
            });
        }
    }
    Connections
    {
        target: ServiceCompositor
        function onFocusedWorkspaceIdChanged()
        {
            if (OverlayState.active && !overlay.authenticating && !ServiceScreenshot.busy) OverlayState.hide(OverlayState.current);
        }
    }
    Connections
    {
        target: ServiceLock
        function onLockedChanged()
        {
            if (!ServiceLock.locked) return;
            overlay.dismiss();
            if (OverlayState.active) OverlayState.hide(OverlayState.current);
        }
    }

    Component.onCompleted:
    {
        holdOutput();
        loadContent();
    }

    Rectangle
    {
        anchors.fill: parent
        color: "#000000"
        opacity: Math.max(OverlayState.mounted === "desktopMenu" ? 0 : overlay.contentReveal * 0.6,
            overlay.altTabReveal * 0.6, overlay.polkitReveal * 0.6)
    }
    MouseArea
    {
        anchors.fill: parent
        enabled: overlay.modal
        onClicked: overlay.dismiss()
    }

    Loader
    {
        id: page
        anchors.fill: parent
        enabled: OverlayState.active && !overlay.authenticating && !overlay.switching && !ServiceScreenshot.active
        visible: !overlay.switching
    }
    Loader
    {
        id: switcher
        anchors.fill: parent
        active: overlay.switching || overlay.altTabReveal > 0.001
        enabled: overlay.switching && !overlay.authenticating
        sourceComponent: AltTab { host: overlay }
    }
    Loader
    {
        id: screenshotView
        objectName: "screenshotView"
        anchors.fill: parent
        active: ServiceScreenshot.active
        enabled: !overlay.authenticating
        sourceComponent: Screenshot { }
    }
    Rectangle
    {
        anchors.fill: parent
        color: "#000000"
        opacity: OverlayState.mounted !== "" ? overlay.polkitReveal * 0.6 : 0
    }
    Loader
    {
        anchors.fill: parent
        active: overlay.authenticating || overlay.polkitReveal > 0.001
        enabled: overlay.authenticating
        sourceComponent: Polkit { host: overlay; agent: authAgent }
    }
}
