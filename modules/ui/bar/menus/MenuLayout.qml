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

            ButtonList
            {
                filled: true
                selected: layout.index === ServiceCompositor.keyboardLayoutIndex
                icon: Icon.keyboard
                text: layout.modelData
                trailing: selected ? "" : ServiceCompositor.shortLayout(layout.modelData)

                onClicked:
                {
                    ServiceCompositor.setKeyboardLayout(layout.index);
                    MenuState.close();
                }
            }
        }
    }
}
