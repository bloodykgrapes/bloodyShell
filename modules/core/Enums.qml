pragma Singleton

import Quickshell

Singleton
{

    enum Edge { EdgeTop = 0, EdgeBottom = 1, EdgeLeft = 2, EdgeRight = 3 }
    enum EqualizerStyle { EqualizerBars = 0, EqualizerWaves = 1 }
    enum PanelStyle { PanelDisabled = -1, InFrame = 0, OutFrame = 1 }
    enum BarStyle { BarCenter = 4, BarLeft = 5, BarRight = 6, BarFull = 7, BarWaves = 8 }
    enum AnimationMode { AnimationsDisabled = 0, AnimationsStandard = 1, AnimationsFluid = 2 }
    enum ThemeStyle { ThemeLight = 0, ThemeDark = 1, ThemeAuto = 2, ThemeWallpaper = 3 }
    enum AccentMode { AccentAuto = 0, AccentCustom = 1 }
    enum HighlightStyle { HighlightRed = 0, HighlightOrange = 1, HighlightYellow = 2, HighlightAccent = 3, HighlightCustom = 4 }
    enum MotionStyle { MotionDirect = 0, MotionFluid = 1, MotionGlide = 2 }
    enum ShellSurface { SurfaceSolid = 0, SurfaceBackdrop = 1, SurfaceBlur = 2 }
    enum ScreenshotMode { ScreenshotArea = 0, ScreenshotScreen = 2 }
    enum WallpaperPause { PauseNever = 0, PauseFullscreen = 1, PauseCovered = 2 }
    enum WindowBorder { BorderOff = 0, BorderFocused = 1, BorderAll = 2 }
    enum WindowColor { ColorAccent = 0, ColorGray = 1, ColorWhite = 2 }
    enum WindowAnimation { WindowNiri = 0, WindowBouncy = 1, WindowInstant = 2 }
    enum LauncherStyle { LauncherFloating = 0, LauncherIsland = 1 }
}
