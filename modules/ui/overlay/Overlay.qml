pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland

import "../../animations"
import "../../animations/OverlayMotion.js" as Motion
import "../../common"
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
    property Item stackedFocus: null
    readonly property Item currentView: OverlayState.current === OverlayState.stacked ? stackedPage.item : page.item
    readonly property var preparationOrder: ["launcher", "settings", "power", "wallpapers", "helper", "desktopMenu"]
    property var preparedComponents: []
    readonly property bool authenticating: authAgent.isActive
    readonly property bool switching: ServiceAltTab.active
    readonly property bool modal: authenticating || ServiceScreenshot.active || switching || OverlayState.active
    readonly property bool shown: !ServiceLock.locked && (modal || contentReveal > 0.001 || stackedReveal > 0.001 || altTabReveal > 0.001 || polkitReveal > 0.001)
    readonly property bool showingStacked: OverlayState.stacked !== "" && OverlayState.current === OverlayState.stacked

    component RevealEase: Ease
    {
        required property bool opening
        property string name: ""
        property var standardCloseCurve: Theme.easingAccelerate

        duration: opening ? (Config.animationsFluid ? Motion.openDuration(name) : Theme.animationDurationOpen) : OverlayState.closeDuration
        curve: Config.animationsFluid ? (opening ? Motion.openCurve(name) : Motion.fluidCloseCurve)
            : (opening ? Theme.easingEmphasized : standardCloseCurve)
        durationByDistance: true
    }

    property real contentReveal: OverlayState.active ? 1 : 0
    RevealEase on contentReveal { opening: OverlayState.active; name: OverlayState.mounted }
    property real stackedReveal: showingStacked ? 1 : 0
    RevealEase on stackedReveal { opening: overlay.showingStacked; name: OverlayState.stacked }
    property real altTabReveal: ServiceAltTab.presented ? 1 : 0
    RevealEase on altTabReveal { opening: ServiceAltTab.presented; standardCloseCurve: Theme.easingEmphasized }
    property real polkitReveal: authenticating ? 1 : 0
    RevealEase on polkitReveal { opening: overlay.authenticating; standardCloseCurve: Theme.easingEmphasized }

    function activeFor(name)
    {
        if (name === "polkit") return authenticating;
        return OverlayState.current === name && !authenticating && !switching && !ServiceScreenshot.active;
    }
    function revealFor(name) { return name === "polkit" ? polkitReveal : name === OverlayState.stacked ? stackedReveal : contentReveal }
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
    function loadStackedContent()
    {
        const source = Registry.overlaySources[OverlayState.stacked];
        if (source)
        {
            const window = overlay.contentItem.Window.window;
            stackedFocus = window ? window.activeFocusItem : null;
            stackedPage.setSource(source, { host: overlay });
        }
        else
        {
            stackedPage.source = "";
            Qt.callLater(restoreStackedFocus);
        }
    }
    function focusContent()
    {
        if (!OverlayState.active || OverlayState.popupsSuspended || !currentView) return;
        currentView.forceActiveFocus();
    }
    function restoreStackedFocus()
    {
        if (OverlayState.stacked !== "") return;
        const target = stackedFocus;
        stackedFocus = null;
        if (!OverlayState.active || OverlayState.popupsSuspended) return;
        if (target && target.visible && target.enabled) target.forceActiveFocus();
        else focusContent();
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

    screen: Quickshell.screens.find(s => s.name === (ServiceScreenshot.active ? ServiceScreenshot.output : modal || contentReveal > 0.001 || stackedReveal > 0.001 || altTabReveal > 0.001 || polkitReveal > 0.001 ? output : ServiceCompositor.focusedOutput)) || Quickshell.screens[0] || null
    visible: shown
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    mask: authenticating || ServiceScreenshot.active || OverlayState.active ? null : switching ? switcherInput : transientInput
    BackgroundEffect.blurRegion: ShellMaterial.blur ? shellBlur : null

    WlrLayershell.namespace: "bloodyShell:overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: modal ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Region { id: transientInput }
    Region { id: shellBlur; regions: ShellMaterial.blur ? ShellMaterial.regionsFor(overlay.contentItem.Window.window) : [] }
    Region { id: switcherInput; regions: switcher.item && ServiceAltTab.presented ? [switcher.item.inputRegion] : [] }

    PolkitAgent { id: authAgent }
    Binding { target: OverlayState; property: "inhibited"; value: overlay.authenticating || ServiceLock.locked || ServiceScreenshot.active }
    Binding { target: OverlayState; property: "popupsSuspended"; value: overlay.authenticating || ServiceLock.locked || ServiceScreenshot.active || overlay.switching || OverlayState.stacked !== "" }
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
    // Changing outputs recreates the native surface; release its inhibitor before that happens.
    ShortcutInhibitor { window: overlay; enabled: overlay.backingWindowVisible && overlay.modal }

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
                else if (overlay.currentView && OverlayState.active) overlay.currentView.forceActiveFocus();
                overlay.screenshotFocus = null;
            });
        }
    }

    Connections
    {
        target: OverlayState
        function onMountedChanged() { overlay.loadContent() }
        function onStackedChanged() { overlay.loadStackedContent() }
        function onCurrentChanged()
        {
            if (OverlayState.active && !overlay.authenticating && !overlay.switching)
            {
                if (OverlayState.stacked === "") overlay.holdOutput();
                else if (OverlayState.current === OverlayState.stacked) Qt.callLater(() =>
                {
                    if (overlay.currentView && overlay.activeFor(OverlayState.current)) overlay.currentView.forceActiveFocus();
                });
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
                const view = overlay.currentView;
                if (view) view.forceActiveFocus();
            });
        }
    }
    Connections
    {
        target: ServiceCompositor
        function onFocusedWorkspaceIdChanged()
        {
            if (OverlayState.active && !overlay.authenticating && !ServiceScreenshot.busy) OverlayState.close();
        }
    }
    Connections
    {
        target: ServiceLock
        function onLockedChanged()
        {
            if (!ServiceLock.locked) return;
            overlay.dismiss();
            OverlayState.close();
        }
    }

    Component.onCompleted:
    {
        holdOutput();
        loadContent();
        loadStackedContent();
    }

    SurfaceCutout
    {
        objectName: "overlayScrim"
        anchors.fill: parent
        cutout: ShellMaterial.blur ? polkitView.item?.scrimCutout || page.item?.scrimCutout || null : null
        opacity: Motion.scrimOpacity(Math.max(OverlayState.mounted === "desktopMenu" ? 0 : page.item?.reveal ?? 0,
            switcher.item?.reveal ?? 0, polkitView.item?.reveal ?? 0), Config.animationsFluid)
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
        enabled: OverlayState.active && OverlayState.current === OverlayState.mounted && OverlayState.stacked === "" && !overlay.authenticating && !overlay.switching && !ServiceScreenshot.active
        visible: !overlay.switching
    }
    Rectangle
    {
        anchors.fill: parent
        visible: stackedPage.item !== null && !overlay.switching
        color: "#000000"
        opacity: Motion.scrimOpacity(stackedPage.item?.reveal ?? 0, Config.animationsFluid)
        MouseArea { anchors.fill: parent }
    }
    Loader
    {
        id: stackedPage
        objectName: "stackedOverlayPage"
        anchors.fill: parent
        enabled: OverlayState.stacked !== "" && overlay.activeFor(OverlayState.stacked)
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
    SurfaceCutout
    {
        anchors.fill: parent
        cutout: ShellMaterial.blur ? polkitView.item?.scrimCutout ?? null : null
        opacity: OverlayState.mounted !== "" ? Motion.scrimOpacity(polkitView.item?.reveal ?? 0, Config.animationsFluid) : 0
    }
    Loader
    {
        id: polkitView
        anchors.fill: parent
        active: overlay.authenticating || overlay.polkitReveal > 0.001
        enabled: overlay.authenticating
        sourceComponent: Polkit { host: overlay; agent: authAgent }
    }
}
