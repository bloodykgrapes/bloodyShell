pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window

import "../animations"
import "../core"
import "../src/ChoiceOptions.js" as Options

Item
{
    id: dropdown

    property var options: []
    property var current
    property bool open: false
    property bool presented: true
    property string placeholderText: Tr.tr("settings.select")
    property real maxListHeight: Math.min(156, Math.max(40, (Window.window?.height ?? 720) * 0.22))

    readonly property var entries: Options.unique(options)
    readonly property int currentIndex: Options.indexOf(entries, current)
    readonly property var alternatives: entries.filter((_, index) => index !== currentIndex)
    readonly property int optionHeight: 34
    readonly property string currentLabel: currentIndex >= 0 ? Options.label(entries[currentIndex]) : placeholderText

    signal selected(var value)

    width: parent ? parent.width : 240
    implicitHeight: content.implicitHeight
    height: implicitHeight

    function toggle()
    {
        if (enabled && visible && presented && alternatives.length > 0) open = !open;
    }

    function choose(index)
    {
        if (!open || index < 0 || index >= alternatives.length) return;
        const choice = Options.value(alternatives[index]);
        close();
        selected(choice);
    }

    function close()
    {
        if (trigger.enabled) trigger.focusFor(Qt.PopupFocusReason);
        open = false;
    }

    function startSelection()
    {
        list.currentIndex = 0;
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    onOpenChanged:
    {
        if (!open) return;
        MenuState.requestKeyboard(dropdown);
        startSelection();
        list.forceActiveFocus(Qt.PopupFocusReason);
    }

    onAlternativesChanged:
    {
        if (alternatives.length === 0) open = false;
        else if (open) startSelection();
    }
    onEnabledChanged: if (!enabled) open = false
    onVisibleChanged: if (!visible) open = false
    onPresentedChanged: if (!presented) open = false

    Rectangle
    {
        objectName: "inlineMenuDropdownBackground"
        anchors.fill: parent
        radius: Theme.menuControlRadius
        color: Theme.menuControlBackground
        Tint on color {}
    }

    Column
    {
        id: content
        width: dropdown.width

        ButtonList
        {
            id: trigger
            objectName: "menuDropdownTrigger"
            width: dropdown.width
            height: 40
            enabled: dropdown.presented && dropdown.alternatives.length > 0
            filled: true
            surfaceColor: "transparent"
            text: dropdown.currentLabel
            trailingIcon: dropdown.alternatives.length === 0 ? "" : dropdown.open ? Icon.chevronUp : Icon.chevronDown
            onClicked: dropdown.toggle()
            Keys.onDownPressed: if (!dropdown.open) dropdown.toggle()
            Accessible.role: Accessible.ComboBox
            Accessible.expanded: dropdown.open
        }

        Item
        {
            id: optionsPanel
            objectName: "inlineMenuDropdownPanel"

            readonly property int inset: 4
            width: dropdown.width
            height: dropdown.open ? list.height + inset * 2 : 0
            visible: dropdown.open || height > 0.5
            enabled: dropdown.open
            clip: true
            Glide on height { duration: dropdown.open ? Theme.animationDurationControl : Theme.animationDurationClose }

            Rectangle
            {
                x: 12
                width: parent.width - x * 2
                height: 1
                color: Theme.colorHairline
            }

            MenuList
            {
                id: list
                objectName: "inlineMenuDropdownOptions"
                x: optionsPanel.inset
                y: optionsPanel.inset
                width: optionsPanel.width - optionsPanel.inset * 2
                height: Math.min(dropdown.maxListHeight, count * dropdown.optionHeight + Math.max(0, count - 1) * spacing + topMargin + bottomMargin)
                leftMargin: 3
                rightMargin: 3
                model: dropdown.alternatives
                activeFocusOnTab: false
                keyNavigationEnabled: false

                function move(offset)
                {
                    currentIndex = Math.max(0, Math.min(count - 1, currentIndex + offset));
                    positionViewAtIndex(currentIndex, ListView.Contain);
                }

                Keys.onUpPressed: move(-1)
                Keys.onDownPressed: move(1)
                Keys.onReturnPressed: dropdown.choose(currentIndex)
                Keys.onEnterPressed: dropdown.choose(currentIndex)
                Keys.onSpacePressed: dropdown.choose(currentIndex)
                Keys.onEscapePressed: dropdown.close()

                delegate: ButtonList
                {
                    required property int index
                    required property var modelData

                    height: dropdown.optionHeight
                    activeFocusOnTab: false
                    text: Options.label(modelData)
                    filled: list.activeFocus && index === list.currentIndex
                    surfaceColor: Theme.menuControlSelected
                    onClicked: dropdown.choose(index)

                    Accessible.role: Accessible.ListItem
                }
            }
        }
    }
}
