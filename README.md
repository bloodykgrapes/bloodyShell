<h1 align="center">bloodyShell</h1>

<p align="center">
    <b>A desktop shell for <a href="https://github.com/niri-wm/niri">niri</a>, built with Quickshell</b>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/bloodykgrapes/bloodyShell?style=flat-square&label=Version&color=blue" alt="Version">
  <img src="https://img.shields.io/badge/License-GPL--3.0-green?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL">Install</a>
  &bull;
  <a href="https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS">Keybinds</a>
  &bull;
  <a href="https://discord.gg/">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="README.md">English</a>
    &bull;
    <a href="docs/readme/README.ru.md">Русский</a>
    &bull;
    <a href="docs/readme/README.fr.md">Français</a>
    &bull;
    <a href="docs/readme/README.de.md">Deutsch</a>
    &bull;
    <a href="docs/readme/README.ja.md">日本語</a>
  </sub>
</p>

---

<table align="center">
  <tr>
    <td valign="top">
      <table>
        <thead>
          <tr> <th>Distro</th> <th>Support</th> </tr>
        </thead>
        <tbody>
          <tr> <td>Arch</td>   <td align="center">&plus;</td>  </tr>
          <tr> <td>Debian</td> <td align="center">&plus;</td>  </tr>
          <tr> <td>Fedora</td> <td align="center">&plus;</td>  </tr>
          <tr> <td>NixOS</td>  <td align="center">&minus;</td> </tr>
          <tr> <td>Ubuntu</td> <td align="center">&plus;</td>  </tr>
        </tbody>
      </table>
    </td>
    <td valign="top">
      <table>
        <thead>
          <tr> <th>Compositor</th> <th>Support</th> </tr>
        </thead>
        <tbody>
          <tr> <td>Niri</td>     <td align="center">&plus;</td>  </tr>
          <tr> <td>Hyprland</td> <td align="center">&minus;</td> </tr>
          <tr> <td>Sway</td>     <td align="center">&minus;</td> </tr>
        </tbody>
      </table>
    </td>
  </tr>
</table>

> [!WARNING]
> I cannot guarantee the proper operation of untested distributions or compositors. Use them at your own risk. However, if you are able to fully test the functionality of the software on your system and provide feedback, that would be greatly appreciated.

At present, I am physically unable to implement support for additional composers. At this time, bloodyShell is currently tied directly to niri. However, dynamic support for additional popular Wayland composers is scheduled to be implemented in the near future.

## Screenshots

<p align="center">
  <img src="docs/images/image-1.png" alt="bloodyShell wallpaper"  width="49%">
  <img src="docs/images/image-2.png" alt="bloodyShell launcher" width="49%">
  <img src="docs/images/image-3.png" alt="bloodyShell settings" width="98.5%">
</p>

## Installation

Arch, Debian, Fedora, Ubuntu:

```bash
git clone https://github.com/bloodykgrapes/bloodyShell.git
cd bloodyShell
./setup install
```

Setup installs the `bloodyShell` command.

```bash
bloodyShell             # launch the shell
bloodyShell update      # check and install update
bloodyShell doctor      # diagnostic
bloodyShell restart     # reload shell
```


See the [installation guide](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL) for details.

## Documentation

| Page | About what |
|---|---|
|[ARCHITECTURE](https://github.com/bloodykgrapes/bloodyShell/wiki/ARCHITECTURE)|Code structure and architecture|
|[INSTALL](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL)|Installation manual|
|[KEYBINDS](https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS)|All the keybindings|
|[PACKAGES](https://github.com/bloodykgrapes/bloodyShell/wiki/PACKAGES)|Project dependencies|

## Credits

- [**Quickshell**](https://quickshell.outfoxxed.me/): the framework
- [**Niri**](https://github.com/niri-wm/niri): the compositor

---

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/graphs/contributors">Contributors</a>
  &bull;
  <a href="CHANGELOG.md">Changelog</a>
  &bull;
  <a href="LICENSE">License</a>
</p>
