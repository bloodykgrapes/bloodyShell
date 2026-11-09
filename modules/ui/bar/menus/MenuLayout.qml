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
}
