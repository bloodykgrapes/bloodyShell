# Installation

bloodyShell runs on niri with Quickshell. Use recent Quickshell (development
baseline: 0.3.2) and niri 26.04 or newer for background effects.
See [niri's documentation](https://niri-wm.github.io/niri/Window-Effects.html).

Setup has package mappings for Arch, Fedora, Debian, and Ubuntu. Availability
varies by distribution release. Missing packages are reported. These mappings
do not mean every distribution has passed a live desktop test.

## Install

```sh
git clone https://github.com/bloodykgrapes/bloodyShell.git
cd bloodyShell
./setup install
```

Run setup as your normal user. It requests sudo for package/login-manager
changes. Select optional packages needed for your hardware and shortcuts.
Quickshell or awww may need manual installation where repositories do not
provide compatible versions.

## Optional programs

During installation, missing application categories offer a single choice:
web browser, media player, image viewer, and graphical text editor. Recognized
installed applications are kept. Each category includes **None**; choosing it
installs nothing for that category. Quit cancels the optional program selection.
Only packages available through the detected package manager are offered, and
selected programs require a final installation confirmation.

Optional dependency checklists start unchecked. With gum, use arrows to move,
X or Tab to toggle, Enter to continue, and Ctrl+A to select or clear all. Checked
rows show `[✓]`; unchecked rows show `[ ]`. App-config selection retains its
existing initial selections. Without gum, numbered menus remain available.

Setup shows an installation plan before making changes. The shell installs into
`~/.config/quickshell/bloodyShell`, and the `bloodyShell` command installs into
`~/.local/bin`. `XDG_CONFIG_HOME` and `XDG_BIN_HOME` override these locations.
When the command directory is missing from `PATH`, setup prints a command to add
it. Shell startup files are preserved; replaced launcher commands are backed up.

Optional app configs are backed up before replacement. Niri imports refresh managed
defaults while preserving user/input/output fragments; see [niri config ownership](../NIRI.md).
Bundled wallpapers can be imported explicitly into `~/Pictures/Wallpapers`. Existing files
are kept; different images with the same name receive a new filename. This is
also the default wallpaper folder in settings.
The bundled niri config starts bloodyShell and awww. To retain your own niri
config, add `spawn-at-startup "qs" "-c" "bloodyShell"` and
`spawn-at-startup "awww-daemon"` instead of replacing it.

Log into niri. The setup helper opens once and can be reopened from
Settings → General. Monitor layout is detected automatically; configure it in
Settings → Display.

```sh
bloodyShell
bloodyShell doctor
```

The diagnostic command only checks tools, assets, and configuration. It makes
no system changes and distinguishes optional tools from missing requirements.

## Networks

Enterprise Wi-Fi in Settings → Networks or the Wi-Fi menu asks for a username
and password. Optional connection settings include the authentication method,
server domain and CA certificate. System certificates are used unless you supply a CA file.
Certificate-based authentication requires a profile configured in your network
manager. Setup installs the Python GObject and libnm bindings; missing bindings
also appear in Settings → Updates → Dependencies.

## Login screen

```sh
./setup greetd
```

This installs the standalone greeter, greetd, and Cage as needed, exports
wallpaper and display preferences into `/var/lib/bloodyShell`, and offers to
enable greetd for the next boot. The greeter uses a fixed black palette. Wallpaper,
animation mode, language, avatars, and clock format update from the shell;
shell colors and accents do not affect the login screen.
The exported wallpaper is readable by the greeter account; choose an image
suitable for the login screen.

The greeter discovers Wayland sessions and supports password/additional PAM
prompts. Enter unlisted accounts manually. Authentication goes through greetd.

Existing greeter files and greetd/PAM configuration are backed up.
GNOME Keyring PAM integration is configured when its module is installed.
The login password and keyring password must match for automatic unlock.

Preview from the source checkout without authenticating or changing the display manager:

```sh
BLOODYSHELL_GREETER_PREVIEW=1 qs -p greeter/shell.qml
```

Close the preview through your compositor. Preview mode disables login and
power confirmation. Test a live greetd login locally before relying on it.

## Recovery

Keep access to a text console and your previous login manager. If login fails,
switch to another TTY, sign in, and inspect:

```sh
journalctl -b -u greetd
journalctl -b -t bloodyShell-greeter
```

Restore `/etc/greetd/config.toml.bak-<timestamp>` or disable greetd and enable
your previous manager, for example:

```sh
sudo systemctl disable greetd
sudo systemctl enable sddm
sudo reboot
```

Replace `sddm` with your previous manager's service. Setup does not stop the
current graphical session.

## Update and rollback

```sh
./setup update
./setup update --beta
./setup update --tag vX.Y.Z
```

After installation, `bloodyShell update` accepts the same options.
Updates stage the download before replacing the shell. App configs are not
reapplied. Backups live under `$XDG_STATE_HOME/bloodyShell/backups/<timestamp>/`
(default: `~/.local/state/bloodyShell/backups/<timestamp>/`).
To roll back, stop the shell, restore the previous directory to
`~/.config/quickshell/bloodyShell`, then start it again.
Update the greeter explicitly with `./setup greetd`.

Settings → Updates → **Import files** provides separate imports for each app
configuration, the login screen, and wallpapers. The section is collapsed by
default. Config imports back up the replaced directory; greeter setup opens in
a terminal for administrator authorization. Wallpaper imports add images while
keeping existing files. Source checkouts use their local resource files;
installed copies download them from the repository's `main` branch.

Installed shell files exclude `dots/`, `greeter/`, and `assets/wallpapers/`.
The `configs` and `greetd` setup commands still work after installation by
fetching the optional files when needed. Updates leave personal wallpapers and
app configurations alone. Existing wallpapers stored inside an older shell
installation are relocated once, including saved bundled wallpaper paths;
custom wallpaper folders stay unchanged.

## Commands

- `./setup install`: packages, shell, optional configs, optional greetd.
- `./setup uninstall`: preview removal; `--apply` stops and removes unchanged installed files.
- `./setup update`: download a release and update the shell.
- `./setup doctor`: read-only diagnostics (`--json` for machine-readable output).
- `./setup configs`: choose app configs to apply.
- `./setup greetd`: install/update the login screen.
- `./setup help`: usage and update options.

## Desktop command

Uninstall preserves personal settings and backups. Use `./setup uninstall --apply
--restore` to restore unchanged tracked user integrations before removal. Modified
and untracked files are reported and retained; packages and privileged integrations
are kept. See [ownership and uninstall](../OWNERSHIP.md) for details.

`bloodyShell` is an executable wrapper, like iNiR's `inir` command. The terminal
finds it in `PATH`; it starts Quickshell or forwards a request to the running
shell's IPC interface. It works from any directory and does not require keeping
the original source checkout. Installation and updates refresh the wrapper.
All backend commands go through `bloodyShell internal DOMAIN ...`; their grouped
implementations live in `scripts/lib/`. Installation preserves shell startup files.
See [ownership and cleanup](../OWNERSHIP.md) for opt-in integrations and restoration. Development utilities and tests remain in the source
checkout and are excluded from installed copies.

```sh
bloodyShell                     # Start in the background
bloodyShell restart
bloodyShell stop
bloodyShell status
bloodyShell logs
bloodyShell settings
bloodyShell launcher show
bloodyShell wallpapers
bloodyShell screenshot
bloodyShell alt-tab previous
bloodyShell lock
bloodyShell setup               # Installer menu
bloodyShell update
bloodyShell doctor
bloodyShell help
```

Use `bloodyShell run` for foreground debugging. `status --json` provides machine
readable instance details. Panel commands accept `show`, `hide`, or `toggle`.
Panel actions, screenshots, Alt+Tab, lock, and logs discover the newest running
bloodyShell instance in the current desktop session and address its instance ID.
They work even when that instance runs from another checkout. Other Quickshell
configurations and the greeter are excluded.

Start, stop, restart, status, and maintenance remain scoped to the installation
or checkout containing the command. Developers can use `./scripts/bloodyShell run`
to launch a checkout, then use the installed `bloodyShell` command for its actions.
The shell declares `ShellId bloodyShell`; restart older running versions after
updating so they advertise this identity. Refresh the installed command through
setup after updating the wrapper.

While developing, refresh just the command from the checkout:

```sh
install -m755 scripts/bloodyShell "${XDG_BIN_HOME:-$HOME/.local/bin}/bloodyShell"
```
