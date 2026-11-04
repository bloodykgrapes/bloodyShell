pragma Singleton

import Quickshell

Singleton
{

    enum Edge { EdgeTop = 0, EdgeBottom = 1, EdgeLeft = 2, EdgeRight = 3 }
    enum BarStyle { BarDefault = 0, BarFrame = 1, BarFloating = 2, BarIslands = 3 }
    enum DockStyle { DockAttached = 0, DockFloating = 1 }
    enum MenuStyle { MenuAttached = 0, MenuFloating = 1 }
    enum Background { BackgroundSolid = 0, BackgroundBlur = 1, BackgroundTransparent = 2 }
    enum AnimationMode { AnimationsDisabled = 0, AnimationsStandard = 1, AnimationsFluid = 2 }
    enum ThemeStyle { ThemeLight = 0, ThemeGraphite = 1, ThemeDarker = 2, ThemeBlack = 3 }
}
