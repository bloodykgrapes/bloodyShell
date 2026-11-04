<h1 align="center">PACKAGES</h1>

`setup` is the authoritative package catalog. Settings → Updates → Dependencies
shows installed tools and offers package actions through your terminal, keeping
the package manager's normal prompts.

## Core

| Package | Purpose            | 
| :------ | :----------------- |
| `awww`  | Wallpaper daemon   |
| `curl`  | HTTP requests      |
| `tar`   | Archive extraction |

## Quickshell

Quickshell needs Qt Quick, Qt SVG, and Qt Wayland. 

| Package           | Purpose                               |
| :---------------- | :------------------------------------ |
| `quickshell`      | Runs the shell and its QML interfaces |
| `qt6-base`        | Qt core                               |
| `qt6-declarative` | QML runtime modules                   |
| `qt6-svg`         | SVG support                           |
| `qt6-wayland`     | Qt Wayland platform integration       |

## System

### Hardware

| Package          | Purpose |
| :--------------- | :------ |
| `bluez`          |         |
| `brightnessctl`  |         |
| `networkmanager` |         |
| `upower`         |         |
| `wlsunset`       |         |

### Audio

| Package        | Purpose | Required |
| :------------- | :------ | :------: |
| `cava`         |         | No       |
| `easyefffects` |         | No       |
| `pipewire`     |         | Yes      |
| `playerctl`    |         | Yes      |
| `wireplumber`  |         | Yes      |

### Images & Video

| Package        | Purpose          | Required |
| :------------- | :--------------- | :------: |
| `ffmpeg`       | Video processing | Yes      |
| `mpv`          | Media playback   | Yes      |

---

Optional features use brightnessctl, bluetoothctl, wlsunset, ffmpeg, lpstat,
notify-send, cava, playerctl, udisksctl, and pkexec. App shortcuts use Kitty,
Nautilus, and btop. gum enables arrow-key setup menus; numbered menus work
without it.

The login screen needs greetd, Cage, and the package-provided `greeter` account.
GNOME Keyring and its PAM module enable password-based keyring unlock.