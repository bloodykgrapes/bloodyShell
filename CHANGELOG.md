<h1 align="center">CHANGELOG</h1>

<p align="center">
    All notable changes to bloodyShell documented in this file.
</p>

## [0.0.3] - 2026-11-14

### Added
- **Settings:** Action popups.
- **Settings:** A dedicated keyboard shortcuts page.
- **Settings:** The ability to import compositor, dotfiles, login screen, and wallpaper files directly from the Update page.
- **Settings:** Virtual keyboard option when the physical keyboard is not connected.
- **Settings:** Mouse settings on device page.
- **Wallpapers:** Support for video wallpapers.
- **Wallpapers:** Support for configurable wallpaper transition animation styles.

### Changed
- **Core:** Replaced the greetd display manager with SDDM.
- **UI:** The frame now sits atop full-screen windows and will disappear  with animation when the window is maximized to full-screen mode.
- **UI:** Redesigned menus with a sidebar-style appearance.
- **UI:** The media menu now replaces the Dynamic Island content, eliminating duplication of the track title and album cover.
- **Settings:** The default wallpapers directory has been changed to `~/Pictures/Wallpapers`.
- **Settings:** Updated placement of the Displays layout section.
- **Wallpapers**: Updated wallpapers overlay to a more compact design.

### Fixed
- **UI:** Resolved an issue where menu content was not displayed when the bar was positioned anywhere other than the top.
- **UI:** Sidebars are no longer fixed to the top-left and top-right corners; they now follow the bar position.
- **UI:** The bar and dock now track the empty workspace independently, on their own display, rather than on the currently focused one.
- **UI:** Corrected improper sizing of various interface elements.
- **UI:** Resolved an issue where tray icons did not respond to right-click events.

## [0.0.2] - 2026-11-09

### Added
- **UI:** Left and right sidebars.
- **Settings:** Notification configuration options.
- **Settings:** Application autostart configuration options.

### Changed
- **Core:** Refactored the frame calculation logic and revised the underlying structural design.
- **UI:** Refined the visual styling of the Bar, Dock, and Dynamic Island (formerly On-Screen Display) components.
- **UI:** Improved the layout and functionality of menus.
- **UI:** Renamed the On-Screen Display (OSD) component to "Dynamic Island".

## [0.0.1] - 2026-11-03

Initial release