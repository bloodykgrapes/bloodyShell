import QtQuick
import "../../../../common" as Common
import QtQuick.Controls.Basic
import QtQuick.Effects

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Common.InteractiveControl
{
    id: settingsCombo


    property var    options: []
    property var    current
    property string placeholderText: Tr.tr("settings.select")

    signal selected(var value)

    function valueOf(o) { return o !== null && typeof o === "object" ? o.value : o }
    function labelOf(o) { return String(o !== null && typeof o === "object" ? o.label : o) }

    readonly property int currentIndex: options.findIndex(o => String(valueOf(o)) === String(current))
    property bool open: false
    property bool keyboardNavigation: false

    property real preferredWidth: 240
    implicitWidth: Math.round(preferredWidth)
    width: Theme.controlWidth(settingsCombo, implicitWidth)
    height: Theme.settingsControlHeight
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: enabled
    onEnabledChanged: if (!enabled) open = false
    onVisibleChanged: if (!visible) open = false
    onOptionsChanged: if (options.length === 0) open = false

    function toggle()
    {
        if (!enabled || options.length === 0) return;
        open = !open;
    }

    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) toggle(); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) toggle(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) toggle(); event.accepted = true }
    Keys.onDownPressed: event => { if (!open) toggle(); event.accepted = true }
    Keys.onUpPressed: event => { if (!open) toggle(); event.accepted = true }

    Accessible.role: Accessible.ComboBox
    Accessible.name: currentIndex >= 0 ? labelOf(options[currentIndex]) : placeholderText
    Accessible.onPressAction: toggle()

    RenderActivity
    {
        id: activity
        target: settingsCombo
        onActiveChanged: if (!active) settingsCombo.open = false
    }

    function popupHost()
    {
        let p = parent;
        while (p && !p.popupLayer) p = p.parent;
        return p ? p.popupLayer : null;
    }

    function syncModalState() { OverlayState.setPopupActive(settingsCombo, open && !OverlayState.popupsSuspended); }
    Component.onDestruction: OverlayState.setPopupActive(settingsCombo, false)

    Connections
    {
        target: OverlayState
        function onPopupsSuspendedChanged() { settingsCombo.syncModalState(); }
    }

    onOpenChanged:
    {
        syncModalState();
        if (!open)
        {
            if (list.activeFocus && enabled && activity.active) focusFor(keyboardNavigation ? Qt.TabFocusReason : Qt.MouseFocusReason);
            return;
        }
        keyboardNavigation = visualFocus;
        const host = popupHost();
        drop.parent = host || settingsCombo;
        placePopup();
        Qt.callLater(placePopup);
        list.currentIndex = Math.max(0, currentIndex);
        list.positionViewAtIndex(list.currentIndex, ListView.Center);
        list.forceActiveFocus(Qt.PopupFocusReason);
    }

    function placePopup()
    {
        if (!open) return;
        const p = settingsCombo.mapToItem(drop.parent, 0, 0);
        panel.x = Math.max(8, Math.min(p.x, drop.width - panel.width - 8));

        const below = p.y + height + 6, above = p.y - 6 - panel.height;
        panel.upward = !(below + panel.height <= drop.height - 8 || above < 8);
        panel.y = Math.max(8, Math.min(panel.upward ? above : below, drop.height - panel.height - 8));
    }

    function choose(index)
    {
        if (!open) return;
        open = false;
        if (index >= 0 && index < options.length && index !== currentIndex) selected(valueOf(options[index]));
    }

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: field.pressed ? Theme.colorPressed : settingsCombo.hovered || settingsCombo.open || settingsCombo.visualFocus ? Theme.colorHoverStrong : Theme.colorField
        border.width: 1
        border.color: settingsCombo.open || settingsCombo.visualFocus ? Theme.colorAccent : "transparent"
        Tint on color {}
        Tint on border.color {}
    }

    ShellText
    {
        anchors { left: parent.left; leftMargin: 12; right: chevron.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        label: settingsCombo.currentIndex >= 0 ? settingsCombo.labelOf(settingsCombo.options[settingsCombo.currentIndex]) : settingsCombo.placeholderText
        color: settingsCombo.currentIndex >= 0 ? Theme.text1 : Theme.text4
    }

    ShellIcon
    {
        id: chevron
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        icon: Icon.chevronDown
        size: 12
        opacity: settingsCombo.open || settingsCombo.hovered ? 1 : 0.6
        rotation: settingsCombo.open ? 180 : 0
        Ease on rotation { duration: Theme.animationDurationControl }
        Smooth on opacity {}
    }

    MouseArea
    {
        id: field
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: settingsCombo.focusFor(Qt.MouseFocusReason)
        onClicked: settingsCombo.toggle()
    }

    Item
    {
        id: drop

        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        visible: panel.shown > 0.01
        onWidthChanged: settingsCombo.placePopup()
        onHeightChanged: settingsCombo.placePopup()

        MouseArea
        {
            anchors.fill: parent
            enabled: settingsCombo.open
            hoverEnabled: true
            onPressed: mouse => { settingsCombo.keyboardNavigation = false; settingsCombo.open = false; mouse.accepted = true }
            onWheel: wheel => wheel.accepted = true
        }
        HoverHandler { enabled: settingsCombo.open; blocking: true }

        Item
        {
            id: panel

            readonly property real full: Math.min(list.contentHeight + 10, 320, Math.max(0, drop.height - 16))
            readonly property bool scrollable: list.contentHeight + 10 > full
            property bool upward: false

            property real progress: settingsCombo.open ? 1 : 0
            readonly property real shown: Config.animationsEnabled ? progress : settingsCombo.open ? 1 : 0
            Behavior on progress
            {
                enabled: Config.animationsEnabled
                NumberAnimation
                {
                    duration: settingsCombo.open ? Theme.animationDurationOpen : Theme.animationDurationClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: settingsCombo.open ? Theme.easingEmphasized : Theme.easingAccelerate
                }
            }

            width: Math.min(Math.max(settingsCombo.width, 200), Math.max(0, drop.width - 16))
            height: full
            enabled: settingsCombo.open
            onWidthChanged: settingsCombo.placePopup()
            onHeightChanged: settingsCombo.placePopup()
            opacity: Math.min(1, shown * 1.5)
            transform: [
                Scale { origin.y: panel.upward ? panel.height : 0; yScale: 0.92 + 0.08 * panel.shown; xScale: 0.98 + 0.02 * panel.shown; origin.x: panel.width / 2 },
                Translate { y: (panel.upward ? 6 : -6) * (1 - panel.shown) }
            ]

            RectangularShadow
            {
                anchors.fill: card
                radius: card.radius
                blur: 24
                offset.y: 6
                color: Qt.rgba(0, 0, 0, Theme.light ? 0.18 : 0.45)
            }
            Rectangle
            {
                id: card
                anchors.fill: parent
                radius: Theme.radiusLarge
                color: Theme.colorSolid
                border.color: Theme.colorLine
                border.width: 1

                Rectangle { anchors.fill: parent; anchors.margins: 1; radius: parent.radius - 1; color: Theme.settingsColorCard }
            }

            MouseArea { anchors.fill: parent; hoverEnabled: true }

            ListView
            {
                id: list

                anchors { fill: parent; margins: 5; rightMargin: panel.scrollable ? 14 : 5 }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: settingsCombo.options
                currentIndex: -1

                SmoothScroll { view: list }

                highlightFollowsCurrentItem: true
                highlightMoveDuration: Config.animationsEnabled ? 160 : 0
                highlightMoveVelocity: -1
                highlightResizeDuration: 0
                highlight: Item
                {
                    Rectangle { anchors { fill: parent; topMargin: 1; bottomMargin: 1 } radius: Theme.radiusSmall; color: Theme.colorHoverStrong }
                }

                Keys.onEscapePressed: settingsCombo.open = false
                Keys.onUpPressed:     currentIndex = Math.max(0, currentIndex - 1)
                Keys.onDownPressed:   currentIndex = Math.min(count - 1, currentIndex + 1)
                Keys.onReturnPressed: settingsCombo.choose(currentIndex)
                Keys.onEnterPressed:  settingsCombo.choose(currentIndex)

                ScrollBar.vertical: ScrollBar
                {
                    id: bar

                    parent: panel
                    anchors { top: parent.top; bottom: parent.bottom; right: parent.right; topMargin: 6; bottomMargin: 6; rightMargin: 3 }
                    policy: panel.scrollable ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    padding: 0

                    readonly property bool wide: hovered || pressed

                    contentItem: Rectangle
                    {
                        implicitWidth: 8
                        radius: width / 2
                        color: bar.pressed ? Theme.text2 : bar.wide ? Theme.text3 : Theme.text4
                        Tint on color {}

                        transform: Scale { origin.x: 8; xScale: bar.wide ? 1 : 0.5; Behavior on xScale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } } }
                    }
                    background: Rectangle
                    {
                        implicitWidth: 8
                        radius: width / 2
                        color: Theme.colorField
                        opacity: bar.wide ? 1 : 0
                        Smooth on opacity {}
                    }
                }

                delegate: Item
                {
                    id: option

                    required property int index
                    required property var modelData

                    readonly property bool chosen: index === settingsCombo.currentIndex
                    readonly property bool lit:    ListView.isCurrentItem

                    width: list.width
                    height: 34

                    Rectangle
                    {
                        anchors { fill: parent; topMargin: 1; bottomMargin: 1 }
                        radius: Theme.radiusSmall
                        color: Theme.colorCurrent
                        visible: option.chosen && !option.lit
                    }

                    ShellText
                    {
                        anchors { left: parent.left; leftMargin: 10; right: tick.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        label: settingsCombo.labelOf(option.modelData)
                        elide: Text.ElideRight
                        color: option.chosen || option.lit ? Theme.text1 : Theme.text2
                        font.weight: option.chosen ? Font.DemiBold : Font.Normal
                        Tint on color {}
                    }
                    ShellIcon
                    {
                        id: tick
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        icon: Icon.check
                        size: 12
                        visible: option.chosen
                    }

                    MouseArea
                    {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = option.index
                        onClicked: { settingsCombo.keyboardNavigation = false; settingsCombo.choose(option.index); }
                    }
                }
            }
        }
    }
}
