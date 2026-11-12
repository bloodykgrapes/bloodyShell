pragma ComponentBehavior: Bound

import QtQuick

import "../../../common"
import "../../../core"
import "../../../services"

Menu
{
    id: menuLayout

    Repeater
    {
        model: ServiceCompositor.keyboardLayouts

        RevealSection
        {
            id: layout
            required property int    index
            required property string modelData

            shown: menuLayout.presented
            order: index

            MenuItem
            {
                icon: Icon.keyboard
                text: layout.modelData
                trailing: layout.index === ServiceCompositor.keyboardLayoutIndex ? "●" : ServiceCompositor.shortLayout(layout.modelData)

                onClicked:
                {
                    ServiceCompositor.setKeyboardLayout(layout.index);
                    MenuState.close();
                }
            }
        }
    }

    RevealSection
    {
        visible: Config.virtualKeyboardEnabled
        shown: menuLayout.presented && visible
        order: ServiceCompositor.keyboardLayouts.length

        MenuItem
        {
            icon: Icon.keyboard
            text: ServiceVirtualKeyboard.visible ? Tr.tr("keyboard.hide") : Tr.tr("keyboard.show")
            onClicked: { ServiceVirtualKeyboard.toggle(); MenuState.close(); }
        }
    }
}
