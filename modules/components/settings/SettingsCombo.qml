import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects

import ".."
import "../../core"

Item
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

    implicitWidth: 240
    width: implicitWidth
    height: 34
    opacity: enabled ? 1 : 0.4
    onEnabledChanged: if (!enabled) open = false

    function popupHost()
    {
        let p = parent;
        while (p && !p.popupLayer) p = p.parent;
        return p ? p.popupLayer : null;
    }

    Component.onDestruction: if (open) OverlayState.settingsPopup = false

    onOpenChanged:
    {
        OverlayState.settingsPopup = open;
        if (!open) return;
        const host = popupHost();
        drop.parent = host || settingsCombo;
        const p = settingsCombo.mapToItem(drop.parent, 0, 0);
        panel.x = Math.max(8, Math.min(p.x, drop.width - panel.width - 8));

        const below = p.y + height + 6, above = p.y - 6 - panel.height;
        panel.upward = !(below + panel.height <= drop.height - 8 || above < 8);
        panel.y = panel.upward ? above : below;
        list.currentIndex = currentIndex;
        list.positionViewAtIndex(Math.max(0, currentIndex), ListView.Center);
        list.forceActiveFocus();
    }

    function choose(index)
    {
        open = false;
        if (index >= 0 && index < options.length && index !== currentIndex) selected(valueOf(options[index]));
    }

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: field.pressed ? Theme.colorPressed : field.containsMouse || settingsCombo.open ? Theme.colorHoverStrong : Theme.colorField
        border.width: 1
        border.color: settingsCombo.open ? Theme.colorAccent : "transparent"
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
        opacity: settingsCombo.open || field.containsMouse ? 1 : 0.6
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
        onClicked: settingsCombo.open = !settingsCombo.open
    }

    Item
    {
        id: drop

        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        visible: panel.shown > 0.01

        MouseArea
        {
            anchors.fill: parent
            enabled: settingsCombo.open
            hoverEnabled: true
            onPressed: mouse => { settingsCombo.open = false; mouse.accepted = true }
            onWheel: wheel => wheel.accepted = true
        }
        HoverHandler { enabled: settingsCombo.open; blocking: true }

        Item
        {
            id: panel

            readonly property real full:       Math.min(list.contentHeight + 10, 320)
            readonly property bool scrollable: list.contentHeight + 10 > 320
            property bool upward: false

            property real shown: settingsCombo.open ? 1 : 0
            Behavior on shown
            {
                enabled: Config.animationsEnabled
                NumberAnimation
                {
                    duration: settingsCombo.open ? Theme.animationDurationOpen : Theme.animationDurationClose
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: settingsCombo.open ? Theme.easingEmphasized : Theme.easingAccelerate
                }
            }

            width: Math.max(settingsCombo.width, 200)
            height: full
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
                        onClicked: settingsCombo.choose(option.index)
                    }
                }
            }
        }
    }
}
