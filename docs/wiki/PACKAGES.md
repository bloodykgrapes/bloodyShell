<h1 align="center">PACKAGES</h1>

> [!IMPORTANT]
> Package names below use Arch naming. Setup maps them to Fedora, Debian, and Ubuntu where available. Check Settings → Updates → Dependencies or run `bloodyShell doctor` for your system.

---

### Core

These tools are required by the shell and its built-in features.

| Package | Purpose |
| --- | --- |
| `quickshell` | Shell runtime (`qs`) |
| `niri` | Compositor and window/workspace control |
| `awww` | Static wallpapers and transitions |
| `python` | CLI and backend helpers |
| `curl` | Release downloads |
| `glib2` | Appearance settings through `gsettings` |
| `util-linux` | Storage discovery through `findmnt` |

---

### Qt

Quickshell needs Qt Quick, Controls, Dialogs, Effects, Shapes, SVG, and Wayland support. Distributions may split QML modules into separate packages.

| Package | Purpose |
| --- | --- |
| `qt6-base` | Qt core and GUI libraries |
| `qt6-declarative` | QML and Qt Quick modules |
| `qt6-svg` | SVG icons |
| `qt6-wayland` | Wayland platform integration |
| `qt6-multimedia` + `qt6-multimedia-ffmpeg` | Optional video wallpaper playback |

---

### Hardware and Networks

NetworkManager and UPower are required. Bluetooth, brightness, night light, and printer tools are optional.

| Package | Purpose |
| --- | --- |
| `networkmanager` | Network connections and `nmcli` |
| `python-gobject` + `libnm` | Enterprise Wi-Fi authentication |
| `upower` | Battery state |
| `bluez` + `bluez-utils` | Bluetooth management |
| `brightnessctl` | Backlight control |
| `wlsunset` | Night light |
| `cups` + `system-config-printer` | Printer status and configuration |
| `udisks2` | Optional disk mounting |
| `polkit` | Administrator authorization through `pkexec` |

---

### Audio and Media

PipeWire and WirePlumber are required for sound control. Media shortcuts and visualizers have optional tools.

| Package | Purpose |
| --- | --- |
| `pipewire` + `wireplumber` | Audio state and `wpctl` controls |
| `playerctl` | Media keyboard shortcuts |
| `cava` | Audio visualizers |

---

### Images and Video

Capture and image processing are required. A media player is an optional installer choice.

| Package | Purpose |
| --- | --- |
| `grim` | Screen capture |
| `wl-clipboard` | Copy screenshots with `wl-copy` |
| `ffmpeg` | Screenshot cropping, wallpaper colors, and video previews |
| `mpv` or `vlc` | Optional media playback application |

---

### Optional Applications and Login

Applications can be skipped. Choose the browser, file manager, and terminal in Settings → Applications → Default applications; bundled app keybinds use those choices.

| Package | Purpose |
| --- | --- |
| `nautilus` | File manager |
| `kitty` | Terminal |
| `fastfetch` | Terminal system information |
| `btop` | System monitor |
| `libnotify` | Update notifications through `notify-send` |
| `gum` | Interactive installer menus |
| `sddm` | Login screen; requires the Qt 6 greeter and niri |

---

### Native Keyboard Plugins

Setup offers build tools for the Alt+Tab monitor and custom virtual keyboard. Plugins are cached after compilation.

| Package | Purpose |
| --- | --- |
| `gcc` | C++ compiler |
| `pkgconf` | Build dependency discovery |
| `qt6-base` + `qt6-declarative` development files | Qt Quick headers and Qt tools |
| `wayland` development files | Wayland client library and `wayland-scanner` |
| `libxkbcommon` development files | Keyboard layouts and key mapping |

> [!NOTE]
> Quickshell and awww may need manual installation on some distributions. Optional packages enable their listed features. Uninstalling bloodyShell does not remove system packages.
