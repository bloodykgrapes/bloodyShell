<p align="center">
  <img src="../../assets/icons/logo.png" alt="desktop" width="16%">
</p>

<h1 align="center">bloodyShell</h1>

<p align="center">
    <b>Оболочка рабочего стола для <a href="https://github.com/niri-wm/niri">niri</a> на базе Quickshell</b>
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
    Русский
    &bull;
    <a href="README.fr.md">Français</a>
    &bull;
    <a href="README.de.md">Deutsch</a>
    &bull;
    <a href="README.ja.md">日本語</a>
  </sub>
</p>

---

> [!WARNING]
> Я не могу гарантировать корректную работу на непроверенных дистрибутивах и композиторах. Используйте их на свой страх и риск. Однако, если вы сможете полностью протестировать функциональность программного обеспечения на своей системе и поделиться обратной связью, буду весьма признателен.

В настоящее время я физически не могу реализовать поддержку дополнительных композиторов.
bloodyShell в данный момент создан специально для niri.
Поддержка других популярных Wayland-композиторов планируется в будущих выпусках.

## Скриншоты

<p align="center">
  <img src="../../docs/images/image-1.png" alt="desktop"    width="98.5%">
  <img src="../../docs/images/image-2.png" alt="launcher"   width="49%">
  <img src="../../docs/images/image-3.png" alt="settings"   width="49%">
  <img src="../../docs/images/image-4.png" alt="wallpapers" width="98.5%">
</p>

## Установка

Arch, Debian, Fedora, Ubuntu:

```bash
git clone https://github.com/bloodykgrapes/bloodyShell.git
cd bloodyShell
./setup install
```

Setup устанавливает команду `bloodyShell`.

```bash
bloodyShell             # интерактивное меню
bloodyShell start       # запуск оболочки
bloodyShell restart     # перезапуск оболочки
bloodyShell update      # проверка и установка обновлений
bloodyShell doctor      # диагностика
```

Подробности — в [руководстве по установке](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL).

## Документация

| Страница | Описание |
| :--- | :---------- |
|[ARCHITECTURE](https://github.com/bloodykgrapes/bloodyShell/wiki/ARCHITECTURE)|Структура кода и архитектура|
|[INSTALL](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL)|Руководство по установке|
|[KEYBINDS](https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS)|Все горячие клавиши|
|[PACKAGES](https://github.com/bloodykgrapes/bloodyShell/wiki/PACKAGES)|Зависимости проекта|

## Благодарности

- [**Quickshell**](https://quickshell.outfoxxed.me/): фреймворк
- [**niri**](https://github.com/niri-wm/niri): композитор
- [**iNiR**](https://github.com/snowarch/iNiR): источник вдохновения

---

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/graphs/contributors">Участники</a>
  &bull;
  <a href="../../CHANGELOG.md">Список изменений</a>
  &bull;
  <a href="../../LICENSE">Лицензия</a>
</p>