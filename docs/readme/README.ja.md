<h1 align="center">bloodyShell</h1>

<p align="center">
    <b>Quickshell で構築された <a href="https://github.com/niri-wm/niri">niri</a> 用デスクトップシェル</b>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/bloodykgrapes/bloodyShell?style=flat-square&label=Version&color=blue" alt="Version">
  <img src="https://img.shields.io/badge/License-GPL--3.0-green?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL">インストール</a>
  &bull;
  <a href="https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS">キーバインド</a>
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
          <tr> <th>ディストリビューション</th> <th>対応状況</th> </tr>
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
          <tr> <th>コンポジター</th> <th>対応状況</th> </tr>
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
> bloodyShell は niri 専用です。インストーラーは Arch、Debian、Fedora、Ubuntu のパッケージに対応していますが、利用できるパッケージは各リリースによって異なります。NixOS、Hyprland、Sway は現在未対応です。

## インストール

Arch、Debian、Fedora、Ubuntu：

```bash
git clone https://github.com/bloodykgrapes/bloodyShell.git
cd bloodyShell
./setup install
```

インストーラーは `~/.local/bin` に `bloodyShell` コマンドを配置し、PATH を設定します。新しいターミナルを開いてください。niri のキーバインドに反映するには、ログアウトして再ログインしてください。

```bash
bloodyShell             # シェルを起動
bloodyShell update      # 更新を確認してインストール
bloodyShell doctor      # 診断
bloodyShell restart     # シェルを再起動
```

詳細は[インストールガイド](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL)を参照してください。

## ドキュメント

| ページ | 内容 |
|---|---|
|[ARCHITECTURE](https://github.com/bloodykgrapes/bloodyShell/wiki/ARCHITECTURE)|コード構成とアーキテクチャ|
|[INSTALL](https://github.com/bloodykgrapes/bloodyShell/wiki/INSTALL)|インストール・更新・アンインストール|
|[KEYBINDS](https://github.com/bloodykgrapes/bloodyShell/wiki/KEYBINDS)|キーボードショートカット|
|[PACKAGES](https://github.com/bloodykgrapes/bloodyShell/wiki/PACKAGES)|依存パッケージ|

## 謝辞

- [**Quickshell**](https://quickshell.outfoxxed.me/): フレームワーク
- [**Niri**](https://github.com/niri-wm/niri): コンポジター

---

<p align="center">
  <a href="https://github.com/bloodykgrapes/bloodyShell/graphs/contributors">貢献者</a>
  &bull;
  <a href="../../CHANGELOG.md">変更履歴</a>
  &bull;
  <a href="../../LICENSE">ライセンス</a>
</p>
