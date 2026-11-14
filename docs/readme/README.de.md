<h1 align="center">bloodyShell</h1>

<p align="center">
    <b>Eine Desktop-Shell für <a href="https://github.com/niri-wm/niri">niri</a>, entwickelt mit Quickshell</b>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/bloodykgrapes/bloodyShell?style=flat-square&label=Version&color=blue" alt="Version">
  <img src="https://img.shields.io/badge/License-GPL--3.0-green?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL">Installation</a>
  &bull;
  <a href="https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS">Tastenkürzel</a>
  &bull;
  <a href="https://discord.gg/">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a>
    &bull;
    <a href="README.ru.md">Русский</a>
    &bull;
    <a href="README.fr.md">Français</a>
    &bull;
    <a href="README.de.md">Deutsch</a>
    &bull;
    <a href="README.ja.md">日本語</a>
  </sub>
</p>

---

<table align="center">
  <tr>
    <td valign="top">
      <table>
        <thead>
          <tr> <th>Distribution</th> <th>Unterstützung</th> </tr>
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
          <tr> <th>Compositor</th> <th>Unterstützung</th> </tr>
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

> [!NOTE]
> bloodyShell benötigt niri. Der Installer enthält Paketzuordnungen für Arch, Debian, Fedora und Ubuntu; die Verfügbarkeit hängt von der Distributionsversion ab. NixOS, Hyprland und Sway werden derzeit nicht unterstützt.

## Installation

Arch, Debian, Fedora, Ubuntu:

```bash
git clone https://github.com/bloodykgrapes/bloodyShell.git
cd bloodyShell
./setup install
```

Der Installer legt den Befehl `bloodyShell` in `~/.local/bin` ab und richtet den PATH ein. Öffne danach ein neues Terminal. Melde dich für die niri-Tastenkürzel ab und wieder an.

```bash
bloodyShell             # Shell starten
bloodyShell update      # Update suchen und installieren
bloodyShell doctor      # Diagnose
bloodyShell restart     # Shell neu starten
```

Weitere Informationen stehen in der [Installationsanleitung](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL).

## Dokumentation

| Seite | Beschreibung |
|---|---|
|[ARCHITECTURE](https://github.com/bloodykgrapes/bloodyShell/wiki/ARCHITECTURE)|Codestruktur und Architektur|
|[INSTALL](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL)|Installation, Updates und Deinstallation|
|[KEYBINDS](https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS)|Tastenkürzel|
|[PACKAGES](https://github.com/bloodykgrapes/bloodyShell/wiki/PACKAGES)|Projektabhängigkeiten|

## Danksagungen

- [**Quickshell**](https://quickshell.outfoxxed.me/): Framework
- [**Niri**](https://github.com/niri-wm/niri): Compositor

---

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/graphs/contributors">Mitwirkende</a>
  &bull;
  <a href="../../CHANGELOG.md">Änderungsverlauf</a>
  &bull;
  <a href="../../LICENSE">Lizenz</a>
</p>
