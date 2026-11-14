<h1 align="center">bloodyShell</h1>

<p align="center">
    <b>Оболочка рабочего стола для <a href="https://github.com/niri-wm/niri">niri</a> на Quickshell</b>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/bloodykgrapes/bloodyShell?style=flat-square&label=Version&color=blue" alt="Version">
  <img src="https://img.shields.io/badge/License-GPL--3.0-green?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL">Установка</a>
  &bull;
  <a href="https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS">Горячие клавиши</a>
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
          <tr> <th>Дистрибутив</th> <th>Поддержка</th> </tr>
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
          <tr> <th>Композитор</th> <th>Поддержка</th> </tr>
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
> bloodyShell работает с niri. Установщик содержит пакеты для Arch, Debian, Fedora и Ubuntu; их доступность зависит от версии дистрибутива. Поддержки NixOS, Hyprland и Sway пока нет.

## Установка

Arch, Debian, Fedora, Ubuntu:

```bash
git clone https://github.com/bloodykgrapes/bloodyShell.git
cd bloodyShell
./setup install
```

Установщик добавляет команду `bloodyShell` в `~/.local/bin` и настраивает PATH. Откройте новый терминал; для горячих клавиш niri выйдите из сеанса и войдите снова.

```bash
bloodyShell             # запуск оболочки
bloodyShell update      # проверить и установить обновление
bloodyShell doctor      # диагностика
bloodyShell restart     # перезапуск оболочки
```

Подробности — в [руководстве по установке](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL).

## Документация

| Страница | Описание |
|---|---|
|[ARCHITECTURE](https://github.com/bloodykgrapes/bloodyShell/wiki/ARCHITECTURE)|Структура кода и архитектура|
|[INSTALL](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL)|Установка, обновление и удаление|
|[KEYBINDS](https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS)|Горячие клавиши|
|[PACKAGES](https://github.com/bloodykgrapes/bloodyShell/wiki/PACKAGES)|Зависимости проекта|

## Благодарности

- [**Quickshell**](https://quickshell.outfoxxed.me/): фреймворк
- [**Niri**](https://github.com/niri-wm/niri): композитор

---

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/graphs/contributors">Участники</a>
  &bull;
  <a href="../../CHANGELOG.md">История изменений</a>
  &bull;
  <a href="../../LICENSE">Лицензия</a>
</p>
