<h1 align="center">INSTALL</h1>

> [!IMPORTANT]
> Run setup as your normal user. Install niri before starting the shell. Package mappings cover Arch, Fedora, Debian, and Ubuntu; package availability varies by release. Setup requests sudo for packages and SDDM.

---

### Install

```sh
git clone https://github.com/bloodykgrapes/bloodyShell.git
cd bloodyShell
./setup install
```

Review the installation plan and select optional programs, configs, and login-screen setup. Missing Quickshell or awww packages may require manual installation. See [Packages](PACKAGES.md).

Setup installs `bloodyShell` in `~/.local/bin` and manages PATH entries for shell profiles and user services. Open a new terminal afterward; log out and back in so niri keybinds inherit PATH.

| Location | Contents |
| --- | --- |
| `~/.config/quickshell/bloodyShell` | Shell runtime |
| `~/.config/bloodyShell/settings.json` | Shell settings |
| `~/.local/bin/bloodyShell` | CLI command |
| `~/.local/state/bloodyShell/backups/` | Installation and import backups |
| `~/Pictures/Wallpapers` | Default wallpaper folder |

`XDG_CONFIG_HOME`, `XDG_BIN_HOME`, and `XDG_STATE_HOME` override the corresponding locations.

---

### Start

```sh
bloodyShell
bloodyShell settings
bloodyShell doctor
```

The setup helper opens on first launch. Reopen it from Settings → General. Configure monitors in Settings → Display and keyboard/mouse input in Settings → Devices.

The bundled niri config starts the shell and awww. If keeping your own config, add:

```kdl
spawn-at-startup "awww-daemon"
spawn-sh-at-startup "qs -n -c bloodyShell"
```

---

### Configs and Wallpapers

Use `./setup configs` or Settings → Updates → Import files.

| Import | Action |
| --- | --- |
| Compositor | Refresh niri defaults; preserve `05-user.kdl`, `06-user-input.kdl`, and `07-user-output.kdl` |
| Dots | Replace selected application configs after backing them up |
| Login screen | Open SDDM setup in a terminal; requires sudo |
| Wallpapers | Add bundled images without replacing existing files |
| CLI | Refresh the command and PATH from the current shell files |

Config and wallpaper imports use `dots/` from a source checkout. Installed copies fetch resources from the repository. CLI refresh uses local shell files. Shell updates refresh the CLI but do not reapply configs or wallpapers.

---

### Login Screen

```sh
./setup sddm
```

Installs the Qt 6 SDDM theme and configures Wayland through a separate niri instance. Setup backs up replaced files and asks before switching the enabled display manager; the current session keeps running.

| Location | Contents |
| --- | --- |
| `/usr/share/sddm/themes/bloodyShell` | Login theme and keyboard |
| `/etc/sddm.conf.d/zz-bloodyShell.conf` | SDDM theme and Wayland configuration |
| `/var/lib/bloodyShell` | Shared appearance files |

Avatar and wallpaper sharing is automatic. Videos export a still frame. Language, animation mode, and clock format also follow the shell; the login screen uses its own fixed palette. Exported images are readable by other users.

If login fails, switch to a TTY and inspect `journalctl -b -u sddm`. Restore the setup-created `.bak-*` files or re-enable your previous display-manager service. Test a local login before relying on the new setup.

---

### Updates and Removal

```sh
bloodyShell update
bloodyShell update --beta
bloodyShell update --tag vX.Y.Z
```

`--beta` includes prereleases; `--tag` selects one release. Update the login theme separately with `./setup sddm`. To roll back the shell, stop it, restore the runtime backup to `~/.config/quickshell/bloodyShell`, and start it again.

To refresh only the CLI from a checkout, run `./setup cli`. After updating, `bloodyShell cli` also works. The action keeps the runtime unchanged and backs up a replaced command.

```sh
./setup uninstall                   # Preview
./setup uninstall --apply           # Remove the shell, CLI, cache and temporary files
```

Interactive removal asks **Delete SDDM theme?** and **Delete shell settings?** when those files exist. Both default to No. For scripts, use `--delete-sddm` and/or `--delete-settings` with `--apply` to select them explicitly.

SDDM removal deletes the bloodyShell theme, its SDDM drop-in and shared login images; it requires sudo. The SDDM package and service stay installed. Shell settings removal deletes `~/.config/bloodyShell`; niri and application configs stay untouched.

---

### Commands

| Command | Action |
| --- | --- |
| `bloodyShell run` | Run in the foreground for debugging |
| `bloodyShell restart` / `stop` | Restart or stop the shell |
| `bloodyShell status` / `logs` | Inspect the running instance |
| `bloodyShell launcher` / `settings` / `wallpapers` | Toggle an overlay |
| `bloodyShell screenshot` | Open screenshot capture |
| `bloodyShell lock` | Lock the session |
| `bloodyShell setup` | Open the installer menu |
| `bloodyShell doctor` | Check dependencies and configuration without changing them |
| `bloodyShell help` | List commands and options |

> [!IMPORTANT]
> Uninstall deletes the runtime folder as a whole, including edits inside it. Niri configs, application configs, wallpapers, backups and packages are kept. Shell settings and the SDDM theme are optional removals. Keep a working TTY available when changing the login screen.
