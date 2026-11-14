<h1 align="center">ARCHITECTURE</h1>

> [!IMPORTANT]
> The shell targets niri. Compositor defaults are imported separately; shell startup does not rewrite them.

---

### Code Structure

| Path | Purpose |
| --- | --- |
| `shell.qml` | Starts services, desktop surfaces, layout, overlays, and the virtual keyboard |
| `modules/animations/` | Shared animation behaviors |
| `modules/common/` | Reusable controls, scrolling, effects, and keyboard UI |
| `modules/core/` | Configuration, theme, translations, registries, and interaction state |
| `modules/services/` | Compositor events, devices, media, updates, and backend requests |
| `modules/src/` | JavaScript helpers and native keyboard plugins |
| `modules/ui/` | Bar, dock, desktop, frame, sidebars, lock screen, and overlays |
| `scripts/bloodyShell` | CLI and backend entry point |
| `scripts/lib/` | Installation, resources, desktop integration, networking, storage, and capture |
| `scripts/tests/` | Isolated regression checks; excluded from installation |
| `assets/` | Fonts, icons, shaders, and application assets |
| `dots/` | Application configs, niri defaults, SDDM theme, and wallpapers; imported separately |
| `translations/` | UI language files |

Feature controls live in their feature's `components/` directory. Settings pages are in `modules/ui/overlay/settings/pages/`.

---

### Surfaces

| Surface | Responsibility |
| --- | --- |
| Desktop | Bottom layer on each output; wallpaper effects, video playback, equalizer, and context menu |
| Layout canvas | Overlay layer on each output; frame, bar, dock, Dynamic Island, and sidebars |
| Edge reservations | Four input-free surfaces per output; reserve space for the frame and visible fixed panels |
| Overlay | Shared host for launcher, settings, wallpapers, Alt+Tab, screenshots, and authentication |
| Session lock | Dedicated `WlSessionLock` surfaces |
| Virtual keyboard | Separate surface above applications; shared keyboard UI on shell, lock, and login screens |

`Frame.qml` combines component geometry and input regions. `FrameSurface.qml` draws joined backgrounds with the frame shader. The canvas and overlays ignore exclusive zones; only edge reservations change application margins.

Fullscreen state follows each output's active workspace. The frame, bar, and dock hide smoothly; bar and dock hover triggers stop accepting input. The Dynamic Island continues to show status changes and notifications, while its music widget stays hidden.

Desktop blur affects only the wallpaper. Window Presented mode follows windows on that output's active workspace. Static wallpaper transitions use awww; videos play silently, loop, and pause while locked.

---

### State and Backend

`Config.qml` validates and saves settings. Services own system state; UI components subscribe while needed. `RenderActivity.qml` stops work for hidden views, `Clients.js` tracks shared consumers, and `ModelSync.js` updates models without rebuilding unchanged rows.

QML runs backend operations through `Paths.commandFor()`, which calls `bloodyShell internal DOMAIN ...`. `scripts/lib/backend.py` routes requests to the corresponding module. Native Alt+Tab and virtual-keyboard plugins build into the cache and load through `NativeLoader.qml`.

CLI actions find the newest bloodyShell instance in the current desktop session. Start, stop, restart, and maintenance target the command's installation or checkout.

---

### Configuration Ownership

Niri fragments live in `~/.config/niri/bloodyShell/`.

| Fragment | Import behavior |
| --- | --- |
| `00-environment.kdl` | Replaced |
| `01-layout.kdl` | Replaced |
| `02-window.kdl` | Replaced |
| `03-layer.kdl` | Replaced |
| `04-binds.kdl` | Replaced |
| `05-user.kdl` | Preserved |
| `06-user-input.kdl` | Preserved; keyboard and mouse settings |
| `07-user-output.kdl` | Preserved; display settings |

Shell updates replace runtime files. Compositor, Dots, Login screen, and Wallpapers imports are separate actions. Config replacements are backed up; wallpaper imports keep existing images.

SDDM uses `dots/sddm/` and its own niri configuration. Avatar and wallpaper sharing is automatic; video wallpapers export a still frame. Shared files live in `/var/lib/bloodyShell`.

---

### Checks

Run `python3 scripts/tests/run.py`. Checks use temporary configurations and simulated system commands. Native layer placement and display-manager login also need a live graphical-session check.

> [!IMPORTANT]
> Uninstall removes known runtime, CLI, cache and temporary paths without requiring an installation record or per-file hashes. Shell settings and the SDDM theme have separate deletion prompts. Niri configs, application configs, wallpapers and backups stay intact. See [Install](INSTALL.md).
