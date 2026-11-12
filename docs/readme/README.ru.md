<h1 align="center">bloodyShell</h1>

<p align="center">
    <b>Оболочка рабочего стола для <a href="https://github.com/niri-wm/niri">niri</a>, созданная с помощью Quickshell</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-0.0.1-blue" alt="Version">
  <img src="https://img.shields.io/badge/License-GPL--3.0-green" alt="License">
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

> [!WARNING]
> Я не могу гарантировать корректную работу непроверенных дистрибутивов или композиторов. Используйте их на свой страх и риск. Однако, если вы сможете полностью протестировать функциональность программного обеспечения на своей системе и оставить отзыв, я буду вам очень признателен. 

 В настоящее время я физически не могу реализовать поддержку других композиторов. На данный момент bloodyShell напрямую привязан к niri. Однако в ближайшем будущем планируется реализовать динамическую поддержку других популярных wayland композиторов.

## Скриншоты

<p align="center">
  <img src="../images/image-1.png" alt="bloodyShell desktop"  width="49%">
  <img src="../images/image-2.png" alt="bloodyShell launcher" width="49%">
  <img src="../images/image-3.png" alt="bloodyShell settings" width="98.5%">
</p>

## Установка

```bash
git clone https://github.com/bloodykgrapes/bloodyShell.git
cd bloodyShell
./setup install
```

Установщик добавляет команду `bloodyShell`, сохраняя файлы настройки терминала. Если каталог команды отсутствует в `PATH`, установщик выводит команду для его добавления.

```bash
bloodyShell             # запуск оболочки
bloodyShell update      # проверить и установить обновление
bloodyShell doctor      # диагностика
bloodyShell restart     # перезагрузка оболочки
```

Подробности смотрите в [руководстве по установке](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL).

## Keybinds

| Key | Action |
|---|---|
| <kbd>Super</kbd> + <kbd>Number</kbd> | Изменить рабочий стол |
| <kbd>Super</kbd> + <kbd>Arrow</kbd>  | Изменить фокус        |
| <kbd>Super</kbd> + <kbd>Tab</kbd>    | Обзор задач           |
| <kbd>Super</kbd> + <kbd>D</kbd>      | Лаунчер приложений    |
| <kbd>Super</kbd> + <kbd>Y</kbd>      | Обои                  |
| <kbd>Super</kbd> + <kbd>I</kbd>      | Настройки             |
| <kbd>Super</kbd> + <kbd>P</kbd>      | Питание               |

## Documentation

| Page | About what |
|---|---|
|[ARCHITECTURE](https://github.com/bloodykgrapes/bloodyShell/wiki/ARCHITECTURE)|Структура кода и архитектура|
|[INSTALL](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL)|Инструкция по установке|
|[KEYBINDS](https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS)|Все горячие клавиши|
|[PACKAGES](https://github.com/bloodykgrapes/bloodyShell/wiki/PACKAGES)|Зависимости проекта|

## Credits

- [**Quickshell**](https://quickshell.outfoxxed.me/): фреймворк
- [**Niri**](https://github.com/niri-wm/niri): композитор

---

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/graphs/contributors">Contributors</a>
  &bull;
  <a href="CHANGELOG.md">Changelog</a>
  &bull;
  <a href="LICENSE">License</a>
</p>