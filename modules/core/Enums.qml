pragma Singleton

import Quickshell

Singleton
{

    enum Edge { EdgeTop = 0, EdgeBottom = 1, EdgeLeft = 2, EdgeRight = 3 }
    enum EqualizerStyle { EqualizerBars = 0, EqualizerWaves = 1 }
    enum FrameStyle { InFrame = 0, OutFrame = 1, Filled = 2, Islands = 3 }
    enum MenuStyle { MenuDefault = 0, MenuFloating = 1 }
    enum AnimationMode { AnimationsDisabled = 0, AnimationsStandard = 1, AnimationsFluid = 2 }
    enum ThemeStyle { ThemeLight = 0, ThemeDark = 1 }
    enum ScreenshotMode { ScreenshotArea = 0, ScreenshotScreen = 2 }
}
