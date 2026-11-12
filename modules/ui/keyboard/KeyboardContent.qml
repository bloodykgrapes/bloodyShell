import QtQuick

import "../../common/keyboard" as Keyboard
import "../../core"
import "../../services"

Keyboard.Keyboard
{
    engine: ServiceVirtualKeyboard.engine
    layouts: ServiceVirtualKeyboard.layouts
    layoutIndex: ServiceVirtualKeyboard.layoutIndex
    colors: ({
        surface: Theme.colorSolid,
        key: Theme.colorRaised,
        hover: Theme.colorHoverStrong,
        pressed: Theme.colorPressed,
        text: Theme.text1,
        muted: Theme.text3,
        accent: Theme.colorAccent,
        onAccent: Theme.onAccent
    })
    labels: ({
        title: Tr.tr("keyboard.title"),
        loading: Tr.tr("keyboard.loading"),
        unavailable: Tr.tr("keyboard.unavailable"),
        close: Tr.tr("keyboard.hide"),
        space: Tr.tr("keyboard.space"),
        nextLayout: Tr.tr("keyboard.nextLayout"),
        shift: Tr.tr("keyboard.shift"),
        caps: Tr.tr("keyboard.caps"),
        backspace: Tr.tr("keyboard.backspace"),
        enter: Tr.tr("keyboard.enter"),
        symbols: Tr.tr("keyboard.symbols"),
        letters: Tr.tr("keyboard.letters"),
        alternate: Tr.tr("keyboard.alternate")
    })
    family: Theme.fontText
    animations: Config.animationsEnabled
    fluid: Config.animationsFluid
    status: ServiceVirtualKeyboard.status
    onDismissed: ServiceVirtualKeyboard.hide()
    onLayoutSelected: index => ServiceVirtualKeyboard.selectLayout(index)
}
