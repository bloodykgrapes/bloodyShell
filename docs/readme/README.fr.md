<h1 align="center">bloodyShell</h1>

<p align="center">
    <b>Un environnement de bureau pour <a href="https://github.com/niri-wm/niri">niri</a>, créé avec Quickshell</b>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/bloodykgrapes/bloodyShell?style=flat-square&label=Version&color=blue" alt="Version">
  <img src="https://img.shields.io/badge/License-GPL--3.0-green?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL">Installation</a>
  &bull;
  <a href="https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS">Raccourcis</a>
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
          <tr> <th>Distribution</th> <th>Prise en charge</th> </tr>
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
          <tr> <th>Compositeur</th> <th>Prise en charge</th> </tr>
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
> bloodyShell fonctionne avec niri. L’installateur propose des paquets pour Arch, Debian, Fedora et Ubuntu ; leur disponibilité dépend de la version de la distribution. NixOS, Hyprland et Sway ne sont pas encore pris en charge.

## Installation

Arch, Debian, Fedora, Ubuntu :

```bash
git clone https://github.com/bloodykgrapes/bloodyShell.git
cd bloodyShell
./setup install
```

L’installateur ajoute la commande `bloodyShell` dans `~/.local/bin` et configure le PATH. Ouvrez un nouveau terminal ; déconnectez-vous puis reconnectez-vous pour les raccourcis niri.

```bash
bloodyShell             # lancer le shell
bloodyShell update      # rechercher et installer une mise à jour
bloodyShell doctor      # diagnostic
bloodyShell restart     # redémarrer le shell
```

Consultez le [guide d’installation](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL) pour les détails.

## Documentation

| Page | Description |
|---|---|
|[ARCHITECTURE](https://github.com/bloodykgrapes/bloodyShell/wiki/ARCHITECTURE)|Structure du code et architecture|
|[INSTALL](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL)|Installation, mises à jour et désinstallation|
|[KEYBINDS](https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS)|Raccourcis clavier|
|[PACKAGES](https://github.com/bloodykgrapes/bloodyShell/wiki/PACKAGES)|Dépendances du projet|

## Remerciements

- [**Quickshell**](https://quickshell.outfoxxed.me/): framework
- [**Niri**](https://github.com/niri-wm/niri): compositeur

---

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/graphs/contributors">Contributeurs</a>
  &bull;
  <a href="../../CHANGELOG.md">Historique des versions</a>
  &bull;
  <a href="../../LICENSE">Licence</a>
</p>
