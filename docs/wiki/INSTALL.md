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

The shell installs into `~/.config/quickshell/bloodyShell`.
Optional app configs replace selected directories after backing them up.
The bundled niri config starts bloodyShell and awww. To retain your own niri
config, add `spawn-at-startup "qs" "-c" "bloodyShell"` and
`spawn-at-startup "awww-daemon"` instead of replacing it.

Log into niri. The setup helper opens once and can be reopened from
Settings → General. Monitor layout is detected automatically; configure it in
Settings → Display.

```sh
qs -c bloodyShell
./setup doctor
```

The diagnostic command only checks tools, assets, and configuration. It makes
no system changes and distinguishes optional tools from missing requirements.

## Login screen

```sh
./setup greetd
```

This installs the standalone greeter, greetd, and Cage as needed, exports
wallpaper/appearance into `/var/lib/bloodyShell`, and offers to enable greetd
for the next boot. Shell appearance changes update that export when configured.
The exported wallpaper is readable by the greeter account; choose an image
suitable for the login screen.

The greeter discovers Wayland sessions and supports password/additional PAM
prompts. Enter unlisted accounts manually. Authentication goes through greetd.

Existing greeter files and greetd/PAM configuration are backed up.
GNOME Keyring PAM integration is configured when its module is installed.
The login password and keyring password must match for automatic unlock.

Preview without authenticating or changing the display manager:

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

Updates stage the download before replacing the shell. App configs are not
reapplied. Backups live under `~/.cache/bloodyShell/backups/<timestamp>/`.
To roll back, stop the shell, restore the previous directory to
`~/.config/quickshell/bloodyShell`, then start it again.
Update the greeter explicitly with `./setup greetd`.

## Commands

- `./setup install`: packages, shell, optional configs, optional greetd.
- `./setup update`: download a release and update the shell.
- `./setup doctor`: read-only diagnostics (`--json` for machine-readable output).
- `./setup configs`: choose app configs to apply.
- `./setup greetd`: install/update the login screen.
- `./setup help`: usage and update options.