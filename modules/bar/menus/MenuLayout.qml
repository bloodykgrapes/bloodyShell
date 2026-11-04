pragma ComponentBehavior: Bound

import QtQuick

import "../../components/bar"
import "../../core"
import "../../services"

Menu
{
    id: menuLayout

    Repeater
    {
        model: ServiceCompositor.keyboardLayouts

        MenuItem
        {
            required property int    index
            required property string modelData

            icon: Icon.keyboard
            text: modelData
            trailing: index === ServiceCompositor.keyboardLayoutIndex ? "●" : ServiceCompositor.shortLayout(modelData)

            onClicked:
            {
                ServiceCompositor.setKeyboardLayout(index);
                MenuState.close();
            }
        }
    }
}
