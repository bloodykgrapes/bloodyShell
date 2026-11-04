pragma ComponentBehavior: Bound

import QtQuick

import "../components"
import "../core"
import "../services"

Item
{
    id: content

    property bool positioned: false
    property real wheelRemainder: 0

    function prepare()
    {
        positioned = false;
        wheelRemainder = 0;
        Qt.callLater(() =>
        {
            if (ServiceAltTab.active && width > 0 && height > 0) positioned = true;
        });
    }

    onWidthChanged: prepare()
    onHeightChanged: prepare()
    Component.onCompleted: prepare()

    Connections
    {
        target: ServiceAltTab
        function onActiveChanged()
        {
            if (ServiceAltTab.active) content.prepare();
        }
    }

    readonly property real cardWidth: Math.min(width, 296 * Config.themeScale)

    Keys.onReleased: event =>
    {
        if (ServiceAltTab.active && !event.isAutoRepeat &&
            (event.key === Qt.Key_Alt ||
             ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && !(event.modifiers & Qt.AltModifier))))
        {
            ServiceAltTab.confirm();
            event.accepted = true;
        }
    }
    Keys.onPressed: event =>
    {
        if (!ServiceAltTab.active) return;
        if (event.key === Qt.Key_Escape) ServiceAltTab.cancel();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) ServiceAltTab.confirm();
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
            ServiceAltTab.cycle(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
        else if (event.key === Qt.Key_Home) ServiceAltTab.select(0);
        else if (event.key === Qt.Key_End) ServiceAltTab.select(ServiceAltTab.windows.length - 1);
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) ServiceAltTab.cycle(1);
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) ServiceAltTab.cycle(-1);
        else return;
        event.accepted = true;
    }

    Item
    {
        id: deck
        objectName: "altTabDeck"
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom; bottomMargin: 44; topMargin: 8 }
        width: parent.width
        clip: true

        Repeater
        {
            id: cards
            objectName: "altTabCards"
            model: ServiceAltTab.windows

            delegate: Item
            {
                id: card
                required property var modelData
                required property int index
                readonly property bool selected: index === ServiceAltTab.selected
                width: content.cardWidth
                height: deck.height
                x: (deck.width - width) / 2 + (index - ServiceAltTab.selected) * (width + 8)
                Glide on x { enabled: ServiceAltTab.active && content.positioned && Config.animationsEnabled; duration: Theme.animationDurationControl }
                scale: selected ? 1 : 0.94
                Glide on scale { enabled: ServiceAltTab.active && content.positioned && Config.animationsEnabled; duration: Theme.animationDurationControl }

                AltTabCard
                {
                    anchors { fill: parent; margins: 3 }
                    windowData: card.modelData
                }

                MouseArea
                {
                    id: area
                    anchors.fill: parent
                    onClicked:
                    {
                        if (card.selected) ServiceAltTab.confirm();
                        else ServiceAltTab.select(card.index);
                    }
                    onWheel: wheel =>
                    {
                        const delta = wheel.angleDelta.y || wheel.angleDelta.x;
                        content.wheelRemainder += delta;
                        const steps = Math.trunc(content.wheelRemainder / 120);
                        if (steps !== 0)
                        {
                            content.wheelRemainder -= steps * 120;
                            ServiceAltTab.cycle(-steps);
                        }
                        wheel.accepted = true;
                    }
                }
            }
        }
    }

    Rectangle
    {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        width: Math.min(parent.width, hint.implicitWidth + 32)
        height: 30
        radius: 15
        color: Theme.colorSolid
        ShellText
        {
            id: hint
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 24)
            label: Tr.tr("altTab.hint")
            color: Theme.text2
            size: 11
        }
    }
}
