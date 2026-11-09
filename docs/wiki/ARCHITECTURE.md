# Project structure

`assets/` holds fonts, icons, shaders, application assets, and wallpapers. `dots/` contains the optional application configurations installed by `./setup configs`. The login screen stays self-contained in `greeter/`.

The shell modules have six areas:

- `animations/`: shared animation behaviors such as Ease, Glide, Spring, Appear, Smooth, and Tint.
- `common/`: reusable text, icons, effects, equalizers, switches, menu rows, sliders, and notification views.
- `core/`: configuration, theme, translations, registry, and shared interaction state.
- `services/`: system integration and backend operations.
- `src/`: JavaScript helpers and the native keyboard monitor in `src/keyboard/`.
- `ui/`: bar, desktop, dock, lock screen, Dynamic Island, overlays, frame/layout hosts, and sidebars.

Feature-specific controls live beside their feature in `components/`. Bar widgets and menus have separate folders. Settings components and pages are in `ui/overlay/settings/`; wallpaper content is in `ui/overlay/wallpapers/components/`. Alt+Tab is part of `ui/overlay/altTab/`.

`AltTabKeyboard.qml` owns Alt+Tab's Qt shortcuts, IPC entry point, and Alt-release monitor. Compositor bindings are kept in `dots/niri/bloodyShell/06-binds.kdl`; startup does not edit them. The standalone `scripts/bloodyShell` command separates action definitions and validation, instance discovery, lifecycle control, and maintenance dispatch. Action help is generated from the same definitions used for routing.

The Dynamic Island uses `ui/osd/OSD.qml` and `OSDContent.qml`. Its configuration and service APIs retain their existing names. It is not a second standalone OSD.

The settings switch and menu switch share `common/Toggle.qml`. Settings text and icon buttons share `common/ActionButton.qml`, using a field-style base and separate fading hover/pressed layers. Interaction never interpolates the base fill between opaque and translucent colors. Menu toggle rows build on `common/MenuItem.qml`; the shared control preserves their respective sizes, colors, and hover/press behavior. Feature-specific controls remain local when their presentation or interaction differs.

## Window roles

The shell has three window roles. Desktop uses a bottom-layer surface per output. Layout uses one full-screen canvas and four input-free edge reservation surfaces per output, all created by the single Surface component in `modules/ui/layout/Layout.qml`. Overlay is one shared window for modal content, Alt+Tab, and authentication.

Session locking uses `WlSessionLock` and its lock surfaces independently.

## Canvas and window margins

The Layout canvas anchors to all four output edges, with zero margins and `ExclusionMode.Ignore`. It never assigns `exclusiveZone`: that setter switches a PanelWindow back to normal exclusion mode and would move the canvas inside the work area. Overlay follows the same rule. This behavior is documented by [Quickshell's PanelWindow API](https://quickshell.org/docs/v0.3.2/types/Quickshell/PanelWindow/).

Only the four reservation surfaces assign exclusive zones. Their masks are empty and they accept no keyboard input. `Frame.reservations` calculates each edge from the frame thickness and any non-hiding bar or dock on that edge. Transient island content does not resize application windows. This restores all frame margins without editing compositor configuration or insetting the visible canvas.

## Frame and styling

The shell offers Light and Dark themes in Appearance settings and the setup helper. Dark keeps the default dark palette. Wallpaper accents also tint the frame and its attached surfaces, using a near-black base in Dark so the hue is visible. With accents disabled, the frame returns to black or neutral light.

Shell backgrounds are solid. The frame, attached menus, bar capsules, dock, and floating sidebars share the opaque accent-aware frame color. Lock cards use solid surfaces; lock and greeter wallpapers render directly.

`modules/ui/frame/Frame.qml` owns the scene. Bar, dock, island, and sidebar items expose their actual geometry and input regions. `FrameSurface.qml` draws the surround and attached content in one shader pass using `assets/shaders/frame.frag.qsb`. Smooth unions produce the changing joins as content grows, hides, or slides.

Bar and dock have independent In Frame / Out Frame / Filled / Islands settings. Islands draws detached rounded backgrounds around each bar group and the dock, leaving a gap from the frame; its bar gap is included in reservations and sidebar clearance. The Dynamic Island always uses In Frame and follows the bar side, including when the bar is disabled. Its enabled setting remains independent. In Frame contributes the element's geometry to the shared fill; Out Frame leaves its content without that fill. Filled joins the frame across the entire selected screen edge. Content keeps its existing position while the shared frame shader fills the strip and joins its corners. Bodies covered by a Filled strip on the same edge are omitted from the shader input so smooth unions do not thicken overlapping backgrounds. Content and input regions remain independent. The surround remains visible. Light retains contrasting light surfaces.

`SettingsStyleCard.qml` is shared with Appearance settings. One compact frame preview is reused by the bar and dock style controls. It uses the frame renderer, with the same 150-pixel width, preview borders, labels, and hover motion as Appearance cards. The preview surround is six pixels thick to keep the frame visible at thumbnail size. The bar page uses the same cards for Default and Floating menus. Pointer, keyboard, and accessibility actions select the corresponding style. Menu content anchors to the edge nearest its bar. Reveal progress is independent from animated content dimensions, so resizing a floating menu grows it away from that edge without replaying part of its entrance.

## Bar and sidebars

The tray menu uses the shared menu layout, a bounded app grid, and a rounded actions card. Its width fits the visible icons when no app menu is open. `Menu.centerOnWidget` keeps the tray centered on its bar button within screen bounds, without snapping a compact menu to the bar group's edge. `TrayMenuEntry.qml` renders native menu separators, disabled actions, checkboxes, and radio options in compact rows with shared button interactions and bounded staggered entrances. App actions replay their entrance on submenu navigation and reopening. The card retains its content during its closing fade, disables interaction immediately, and reverses its expansion when reopened quickly. Animations-off settles the card and rows immediately. Submenus reset their scroll position; changing or removing the selected app clears the previous submenu. Left, right, and middle clicks preserve app activation, context menu, and secondary-action behavior.

The bar has fixed groups: workspaces and window name at the start, tray/status/clock/notifications/update at the end. The island is a separate item, not part of either bar group. There is no widget-order editor or system widget. The notifications widget follows the clock and opens notification history, DND, and clear controls. It shows the unread count and marks history read whenever its menu opens.

Each half of the full bar strip opens its corresponding sidebar; hovering anywhere in that half reveals the corner arrow. Widget controls keep their individual actions, and open menus retain their own hit regions. Auto-hide keeps the strip revealed while it is hovered. A shared outside-click area in Frame sits behind shell controls, so bar, island, dock menus, and sidebars can replace one another on the first click. Menus remember the last focused application when opened from a sidebar, allowing compositor focus restoration without immediately dismissing the new menu.

`modules/ui/sidebars/left/LeftSidebar.qml` contains account information, shell shortcuts, and session actions. `modules/ui/sidebars/right/RightSidebar.qml` contains quick controls and media. Their shared Sidebar FocusScope handles revealing, scrolling, geometry, dismissal, and output ownership. Sidebar placement clears the actual bar on its output on all four edges, leaving enough space for the frame shader smoothing. `Config.barMenu` applies to menus and sidebars: Default joins their backgrounds to the frame; Floating adds a ten-pixel edge gap for sidebars and renders their rounded backgrounds separately, excluding their geometry from the frame shader. Floating bar menus disable smoothing at panel joins. The scroll viewport includes horizontal padding for hover scaling. The background expands from its edge with the same Glide behavior as bar menus, while fixed-width content fades in and uses the menu Spring expansion in Fluid mode. The reveal clips content without reflowing text, preserves motion on reversal, and follows the selected animation mode. `SidebarState` closes drawers when higher-priority interactions open.

The left sidebar presents a user card that opens User settings, a wallpaper card, Launcher/Settings buttons, and Reload/Power buttons. `common/WallpaperPreview.qml` is shared with Appearance settings, including its crop, filename, change action, and hover zoom; hidden previews release their image source. Bar menus and sidebars share `common/RevealSection.qml` for staggered fades, vertical motion, and Fluid scaling. These transforms preserve layout dimensions and control hover animations. `SidebarSection.qml` binds the reveal to its drawer; `MenuSlot.qml` binds menu presentation to its open state so reopening a retained menu reverses its reveal. Animation delays are capped, and animations-off applies the state immediately.

The control center shares `ControlToggle` and `ControlSlider` components for fully highlighted Wi-Fi/Bluetooth tiles and compact volume, microphone, and brightness fills. Sliders support drag, wheel, keyboard, mute, and unavailable-device states. Clipped duplicate readouts preserve contrast across the filled region. Media remains visible when paused and disappears when no player is available; its loader stays stable while the sidebar is open, and hidden content releases its playback and visualizer subscriptions.

## Screenshots

`ServiceScreenshot` captures the active output once with grim before presenting the selector. The existing Overlay window loads the screenshot view above its current page, leaving Settings or Launcher mounted and restoring its focus when capture ends. The screenshot view never creates another PanelWindow. Authentication and session locking cancel capture, and failed exports keep the selection open for retry.

`CaptureSelection.qml` handles area dragging, movement, resizing, and full-screen selection. `Config.screenshotMode` stores the integer selection mode; `Config.screenshotSave` stores the boolean destination. Logical selection edges map to the captured PNG's actual pixel dimensions, including fractional monitor scales.

`scripts/runtime/screenshot` owns private runtime capture directories, grim capture, ffmpeg PNG cropping, file saves, and wl-clipboard publication. Cropping reads the frozen source instead of capturing the desktop again or exporting the QML view, preserving native pixels and excluding selectors and selection decorations. Save uses unique filenames under XDG Pictures/Screenshots. Copy uses an independent systemd user service when available, with a normal wl-copy fallback. Completed and cancelled sessions remove their temporary files.

## Dynamic Island

`modules/ui/osd/OSD.qml` is a persistent host with its own enabled setting. It follows the bar edge and always joins the frame. Disabling or hiding the bar does not unload it. It owns its menu, input region, and frame geometry.

`ServiceIsland` combines value events from ServiceOSD, filtered notifications from ServiceNotifications, and MPRIS state from ServiceMedia. Value changes take priority on their originating output, followed by queued notifications, then playing media. With no content, the island collapses.

Notification content wraps into a larger card on every edge, with up to two title lines and four body lines. The island opts into cross-axis sizing in the shared widget slot and zone, so the frame and input region follow its animated dimensions without changing application reservations. Expanded cards carry an opaque frame-colored surface above other shell content, preventing a same-edge dock from showing through. Media and value events retain the compact size. Content transitions fade and slide toward/from the active edge; rapid updates keep the latest pending content, and disabling animations settles immediately.

The widget stays active while its media menu is open, including during temporary playback stops or player removal between tracks. Metadata updates change the displayed fields without recreating the widget or menu. Notifications pause their timeout while covered by a value event or an open media menu on their output. DND suppresses normal popups; critical notifications remain eligible. Locking clears transients. The Notifications settings page collects pop-up behavior, dock badges, and lock-screen notification privacy. DND stays session-only by default; enabling `notificationsRememberDnd` saves the current state in `notificationsDnd` and restores it on startup. Disabling persistence clears the saved state without changing the current session.

## Overlay

`Registry.overlaySources` maps names to visual content. `OverlayState` holds one current name and one mounted name. Closing clears the current name immediately and unloads mounted content after its exit animation; reopening cancels cleanup.

`OverlayView.qml` supplies a FocusScope and animation/dismissal functions without creating a window. Authentication appears above existing content and preserves its drafts and focus scope. Alt+Tab uses the same host from its first keypress, while its cards retain the presentation delay. The native keyboard monitor stays loaded between sessions.

## Applications and autostart

The Applications settings page keeps its installed-application search in the fixed `SettingsPage.header` slot while the page contents scroll. Header input is separated from scrolling content and intercepts clicks above it. It uses `SettingsAutostart.qml` for its collapsible startup list and searchable installed-application picker. The picker shows at most four static matches without its own scroll area; typing refines the matches. Wheel and touchpad scrolling move the surrounding page normally, including while the picker is open. `ServiceApplications` owns discovery, add/remove actions, enable state, session support, and errors. File watching is active only while an Applications page is visible; client registration handles overlapping page transitions.

`scripts/runtime/autostart` reads the effective XDG autostart entries using user-first filename precedence. Changes write atomically to `$XDG_CONFIG_HOME/autostart`, with system entries controlled through user overrides. Desktop-entry commands, field codes, localized metadata, action sections, and unknown keys are preserved. Disabling an entry sets `Hidden=true`; enabling also handles the GNOME autostart flag and restores full metadata for minimal system masks. Only user entries without a system default can be removed.

Niri's systemd session launches the entries at login through `xdg-desktop-autostart.target`. Saving changes or restarting bloodyShell does not launch them. The UI reports unavailable session support and desktop/executable restrictions. Existing niri `spawn-at-startup` configuration is independent of this list.

## Wi-Fi authentication

`ServiceNetwork` handles Wi-Fi connections and authentication failures. `common/WifiCredentials.qml` shares the sign-in form between the bar and Networks settings. `scripts/runtime/network-auth` uses Python GObject and libnm, receiving credentials over stdin. New PEAP/TTLS profiles accept username and password, with optional server domain and CA certificate settings. Certificate validation uses system trust or a supplied CA file. Saved profiles retain their EAP and certificate configuration. New profiles are saved after successful authentication.

## Runtime activity

`common/RenderActivity.qml` tracks view visibility, window visibility, dimensions, and ancestor opacity. `common/Menu.qml` and `SettingsPage.qml` expose this as `active`. Scanning, device/storage watchers, busy pulses, visualizers, and page clocks use that state. `src/Clients.js` keeps service subscriptions idempotent so closing one view does not stop another view's consumer. Background audio visualization stops while locked; lock-screen media position updates remain available.

`src/ModelSync.js` reconciles keyed ListModels without replacing surviving delegates. Dock, workspaces, network lists, and mounted volumes share it. It accepts a role name or a key function and reports whether anything changed. Launcher search caches normalized metadata and alphabetical order when desktop entries change. `common/Equalizer.qml` selects Bars or Waves from `Config.equalizerStyle` by default; the Dynamic Island explicitly keeps Bars. Appearance settings uses the shared style cards with synthetic samples and hover previews; previews do not subscribe to live audio. Bars retains its layout, while Waves uses a closed cubic curve with at most 32 samples and one frame-driven smoothing pass with a faster rise and slower fall. Equalizers share their gradient and resample once per active view; liquid battery waves cache their spatial trigonometry.

Appearance startup reads the current system settings and icon theme. Theme and font enumeration runs when Appearance settings requests it.

## Installation and commands

`scripts/bloodyShell` is the standalone desktop command. Its action commands and logs find the newest bloodyShell instance in the current desktop session and target its ID. Lifecycle and maintenance commands use the selected installation or source checkout. Setup copies the command into the user's bin directory and refreshes it on updates.

Script helpers are grouped by purpose:

- `scripts/runtime/`: system appearance, XDG autostart, network authentication, storage, screenshots, dependency operations, niri configuration writes, and the native keyboard builder. QML callers use `Paths.runtimeScriptsDir`.
- `scripts/setup/`: command installation, greetd PAM integration, and read-only Doctor diagnostics.
- `scripts/tools/`: development utilities, including icon generation.
- `scripts/tests/`: isolated regression fixtures and checks.

Installed copies include runtime and setup helpers and exclude tools and tests. `scripts/setup/install-command` installs the executable atomically, backs up replaced files, and prepares shell startup paths when needed. Managed startup-file symlinks are preserved.

`ServiceUpdate.qml` checks releases on the `Config.updateCheck` schedule. With `Config.updateAuto` enabled, successful checks install the newest eligible release through the existing setup updater, which restarts the shell. Enabling the option also installs an update already found by a successful check. Settings and the installed version must finish loading first; development copies never update themselves. Each successful check permits one automatic installation attempt. A failed installation waits for the next check or a manual retry. `scripts/tests/update_checks.py` covers this flow with fake release responses and an isolated installer.

## Checks

Run `python3 scripts/tests/run.py` for isolated regressions, surface integration, island arbitration, and autostart file/UI checks. Run `python3 scripts/tests/keyboard_checks.py` for the native keyboard monitor. `menu_geometry_checks.py` samples Default and Floating menu backgrounds and content during height/width changes on all four edges and in every animation mode, including compact menu centering; it is included in the main suite. `runtime_checks.py` verifies subscription ownership, delegate preservation, mixed model updates, bounded native model reads, and unchanged liquid-wave geometry.

Source checks validate relative imports and static resource URLs. Surface tests load every settings page and exercise shared switch interactions, alongside all edge reservations, canvas anchoring and the exclusive-zone setter contract, independent island enablement and bar-side alignment, shared visual style controls, full-strip pointer routing and sidebar clearance on all four bar edges, persistent media menus through player removal, sidebar hover padding, and animation reversal. They use isolated configuration and buses with compositor commands disabled. Native layer placement still requires a graphical-session check; the test environment may not access the running niri socket.
