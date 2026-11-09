# Default keybindings

These bindings come with the optional niri config. `Mod` is Super unless
changed in niri.

| Shortcut | Action |
| --- | --- |
| Super + D | Launcher |
| Super + I | Settings |
| Super + P | Power menu |
| Super + Y | Wallpaper selector |
| Super + L | Lock |
| Alt + Tab / Alt + Shift + Tab | Next/previous recent window |
| Super + Tab | niri overview |
| Super + T | Kitty |
| Super + E | Nautilus |
| Super + B | btop in Kitty |
| Super + Q | Close window |
| Print | Screenshot overlay with the remembered selection mode |
| Ctrl + Print | Screen screenshot |

Screenshot bindings use `allow-inhibiting=false` so they also work over Settings
and Launcher. The overlay freezes the current monitor before taking input.
Shell bindings call the `bloodyShell` command, which finds the newest running
bloodyShell instance in the current session. No checkout path is stored in the
bindings. For example, Print runs `bloodyShell screenshot`, and Ctrl+Print runs
`bloodyShell screenshot screen`.
All shell shortcuts live in `dots/niri/bloodyShell/06-binds.kdl`; shell startup
does not generate or rewrite shortcut files.

For configurations that still include the old generated `09-alt-tab.kdl`, remove
its include from `~/.config/niri/config.kdl` before deleting that file. Alt+Tab
and the native switcher disable setting are both in `06-binds.kdl`.
Area selections can be moved and resized; Screen selects the whole monitor. Enter or Capture
performs the selected Copy/Save action, and Escape cancels. Save writes a PNG
to the XDG Pictures directory's `Screenshots` folder.

`Config.screenshotMode` stores Area (0) or Screen (2).
`Config.screenshotSave` is false for Copy and true for Save.
The command `bloodyShell screenshot` opens the overlay; optional arguments
`show`, `screen`, and `hide` open it, select the screen, or cancel it.
