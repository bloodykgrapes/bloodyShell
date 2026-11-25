import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls

import "../../../../animations"
import "../../../../common"
import "../../../../core"
import "../../../../src/ChoiceOptions.js" as Options

Button
{
    id: settingsDropdown

    property var    options: []
    property var    current
    readonly property var entries: Options.unique(options)
    property string placeholderText: Tr.tr("settings.select")

    signal selected(var value)

    readonly property int currentIndex: Options.indexOf(entries, current)
    property bool open: false
    property bool keyboardNavigation: false

    property real preferredWidth: 240
    implicitWidth: Math.round(preferredWidth)
    width: Theme.controlWidth(settingsDropdown, implicitWidth)
    hoverScale: 1
    pressScale: 1
    color: Theme.colorField
    text: currentIndex >= 0 ? Options.label(entries[currentIndex]) : placeholderText
    textColor: currentIndex >= 0 ? Theme.text1 : Theme.text3
    trailingIcon: open ? Icon.chevronUp : Icon.chevronDown
    onClicked: toggle()
    onEnabledChanged: if (!enabled) open = false
    onVisibleChanged: if (!visible) open = false
    onEntriesChanged:
    {
        if (!open) return;
        if (entries.length === 0) close();
        else resetSelection();
    }

    function toggle()
    {
        if (open) close();
        else if (enabled && activity.active && entries.length > 0) open = true;
    }

    Keys.onDownPressed: event => { if (!open) toggle(); event.accepted = true }
    Keys.onUpPressed: event => { if (!open) toggle(); event.accepted = true }

    Accessible.role: Accessible.ComboBox
    Accessible.expanded: open

    RenderActivity
    {
        id: activity
        target: settingsDropdown
        onActiveChanged: if (!active) settingsDropdown.open = false
    }

    function popupHost()
    {
        let p = parent;
        while (p && !p.popupLayer) p = p.parent;
        return p ? p.popupLayer : settingsDropdown.Window.window ? settingsDropdown.Window.window.contentItem : null;
    }

    function syncModalState() { OverlayState.setPopupActive(settingsDropdown, open && !OverlayState.popupsSuspended); }
    Component.onDestruction: OverlayState.setPopupActive(settingsDropdown, false)

    Connections
    {
        target: OverlayState
        function onPopupsSuspendedChanged() { settingsDropdown.syncModalState(); }
    }

    onOpenChanged:
    {
        syncModalState();
        if (!open)
        {
            list.hoveredOption = null;
            list.hoverPositioned = false;
            return;
        }
        keyboardNavigation = visualFocus;
        drop.parent = popupHost() || settingsDropdown;
        resetSelection();
        list.forceActiveFocus(Qt.PopupFocusReason);
    }

    function resetSelection()
    {
        list.hoveredOption = null;
        list.hoverPositioned = false;
        list.currentIndex = Math.max(0, currentIndex);
        list.positionViewAtIndex(list.currentIndex, ListView.Center);
    }

    function close()
    {
        if (!open) return;
        if (list.activeFocus && enabled && activity.active)
            focusFor(keyboardNavigation ? Qt.TabFocusReason : Qt.MouseFocusReason);
        open = false;
    }

    function choose(index)
    {
        if (!open) return;
        const valid = index >= 0 && index < entries.length;
        if (valid) list.currentIndex = index;
        close();
        if (valid && index !== currentIndex) selected(Options.value(entries[index]));
    }

    Item
    {
        id: drop

        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        visible: (settingsDropdown.open || panel.shown > 0) && activity.active && !OverlayState.popupsSuspended

        MouseArea
        {
            anchors.fill: parent
            enabled: settingsDropdown.open
            hoverEnabled: true
            containmentMask: QtObject
            {
                function contains(position: point): bool
                {
                    const field = panel.fieldBounds;
                    return position.x < field.x || position.x >= field.x + field.width
                        || position.y < field.y || position.y >= field.y + field.height;
                }
            }
            onPressed: mouse => { settingsDropdown.keyboardNavigation = false; settingsDropdown.close(); mouse.accepted = true }
            onWheel: wheel => wheel.accepted = true
            HoverHandler { enabled: settingsDropdown.open; blocking: true }
        }

        EdgeReveal { id: reveal; opened: settingsDropdown.open }

        Rectangle
        {
            id: panel
            objectName: "settingsDropdownPanel"

            readonly property rect fieldBounds: ShellMaterial.boundsIn(settingsDropdown, drop.parent)
            readonly property int padding: 5
            readonly property int edgeMargin: 8
            readonly property real fullOptionsHeight: 2 * padding + settingsDropdown.entries.length * list.optionHeight
                + Math.max(0, settingsDropdown.entries.length - 1) * list.spacing
            readonly property real preferredOptionsHeight: Math.min(fullOptionsHeight, 320)
            readonly property real spaceAbove: Math.max(0, fieldBounds.y - edgeMargin)
            readonly property real spaceBelow: Math.max(0, drop.height - fieldBounds.y - fieldBounds.height - edgeMargin)
            readonly property bool upward: preferredOptionsHeight > spaceBelow && spaceAbove > spaceBelow
            readonly property real optionsHeight: Math.min(preferredOptionsHeight, upward ? spaceAbove : spaceBelow)
            readonly property bool scrollable: fullOptionsHeight > optionsHeight
            readonly property real shown: Config.animationsEnabled ? reveal.progress : settingsDropdown.open ? 1 : 0
            readonly property real revealedHeight: optionsHeight * shown

            x: fieldBounds.x
            y: fieldBounds.y - (upward ? revealedHeight : 0)
            width: fieldBounds.width
            height: fieldBounds.height + revealedHeight
            enabled: settingsDropdown.open
            opacity: Math.min(1, shown * 8)
            color: Theme.popupColorBackground
            radius: settingsDropdown.radius

            // Mirror the field's appearance above the popup while the original handles input.
            Button
            {
                objectName: "settingsDropdownHeader"
                y: panel.upward ? panel.revealedHeight : 0
                width: panel.width
                height: panel.fieldBounds.height
                enabled: false
                disabledOpacity: 1
                Accessible.ignored: true
                radius: settingsDropdown.radius
                color:
                {
                    const fill = Qt.tint(Theme.settingsColorCard, settingsDropdown.color);
                    if (settingsDropdown.pressed) return Qt.tint(fill, Theme.colorPressed);
                    return settingsDropdown.highlighted ? Qt.tint(fill, settingsDropdown.hoverColor) : fill;
                }
                text: settingsDropdown.text
                textSize: settingsDropdown.textSize
                textColor: settingsDropdown.textColor
                icon: settingsDropdown.icon
                iconSize: settingsDropdown.iconSize
                iconContent: settingsDropdown.iconContent
                trailingIcon: settingsDropdown.trailingIcon
            }

            Item
            {
                id: optionsViewport
                y: panel.upward ? 0 : panel.fieldBounds.height
                width: panel.width
                height: panel.revealedHeight
                clip: true

                MouseArea { anchors.fill: parent; hoverEnabled: true }

                ListView
                {
                    id: list
                    objectName: "settingsDropdownOptions"

                    // Keep the list laid out at its final size as the surface reveals it.
                    x: panel.padding
                    y: panel.padding + (panel.upward ? optionsViewport.height - panel.optionsHeight : 0)
                    width: Math.max(0, parent.width - x - (panel.scrollable ? 20 : panel.padding))
                    height: Math.max(0, panel.optionsHeight - 2 * panel.padding)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: settingsDropdown.entries
                    spacing: 4
                    currentIndex: -1
                    readonly property int optionHeight: 34
                    property Item hoveredOption: null
                    property real hoverY: 0
                    property bool hoverPositioned: false

                    highlightFollowsCurrentItem: false
                    highlight: SelectionHighlight
                    {
                        objectName: "settingsDropdownHighlight"
                        z: -1
                        y: list.currentItem ? list.currentItem.y : 0
                        width: list.width
                        height: list.currentItem ? list.currentItem.height : 0
                        opacity: list.hoveredOption === null && list.currentIndex !== settingsDropdown.currentIndex ? 1 : 0
                        animate: false
                    }

                    Rectangle
                    {
                        objectName: "settingsDropdownHover"
                        parent: list.contentItem
                        z: 1
                        y: list.hoverY
                        width: list.width
                        height: list.optionHeight
                        radius: 9
                        color: Theme.colorHover
                        opacity: list.hoveredOption !== null ? 1 : 0
                        Glide on y { enabled: Config.animationsEnabled && list.hoverPositioned; duration: 180 }
                        Smooth on opacity { duration: 100 }
                    }

                    SmoothScroll { view: list }

                    function hoverOption(option)
                    {
                        if (!settingsDropdown.open) return;
                        hoverY = option.y;
                        hoverPositioned = true;
                        hoveredOption = option;
                    }

                    function move(offset)
                    {
                        hoveredOption = null;
                        currentIndex = Math.max(0, Math.min(count - 1, currentIndex + offset));
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }

                    Keys.onEscapePressed: settingsDropdown.close()
                    Keys.onUpPressed: move(-1)
                    Keys.onDownPressed: move(1)
                    Keys.onReturnPressed: settingsDropdown.choose(currentIndex)
                    Keys.onEnterPressed:  settingsDropdown.choose(currentIndex)

                    Controls.ScrollBar.vertical: Scrollbar
                    {
                        view: list
                        parent: optionsViewport
                        compact: true
                        anchors { top: list.top; bottom: list.bottom; right: parent.right; rightMargin: 3 }
                        topPadding: 1
                        bottomPadding: 1
                        policy: panel.scrollable ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
                    }

                    delegate: Item
                    {
                        id: option

                        required property int index
                        required property var modelData

                        readonly property bool chosen: index === settingsDropdown.currentIndex
                        readonly property bool highlighted: chosen || (ListView.isCurrentItem && list.hoveredOption === null)

                        width: list.width
                        height: list.optionHeight
                        z: 2

                        Accessible.role: Accessible.ListItem
                        Accessible.name: Options.label(modelData)
                        Accessible.selected: chosen
                        Accessible.onPressAction: settingsDropdown.choose(index)

                        SelectionHighlight
                        {
                            objectName: "settingsDropdownSelectedBackground"
                            anchors.fill: parent
                            visible: option.chosen
                            animate: false
                        }

                        ShellText
                        {
                            anchors { left: parent.left; right: parent.right; margins: 8; verticalCenter: parent.verticalCenter }
                            label: Options.label(option.modelData)
                            size: Theme.controlTextSize
                            elide: Text.ElideRight
                            color: option.highlighted ? Theme.text1 : Theme.text2
                            font.weight: option.highlighted ? Font.DemiBold : Font.Medium
                            Tint on color {}
                        }
                        MouseArea
                        {
                            id: pointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.hoverOption(option)
                            onExited: if (list.hoveredOption === option) list.hoveredOption = null
                            onClicked: { settingsDropdown.keyboardNavigation = false; settingsDropdown.choose(option.index); }
                        }
                    }
                }
            }
        }
    }
}
