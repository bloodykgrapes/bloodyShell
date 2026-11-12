pragma ComponentBehavior: Bound

import QtQuick

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"

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

    readonly property real cardWidth: Math.min(width, 296)
    readonly property real cardSpacing: 10

    function scroll(pixelDelta, angleDelta)
    {
        wheelRemainder += Config.scrollDelta(pixelDelta, angleDelta);
        const steps = Math.trunc(wheelRemainder / 48);
        if (steps === 0) return;
        wheelRemainder -= steps * 48;
        ServiceAltTab.cycle(-steps);
    }

    Keys.onReleased: event =>
    {
        if (ServiceAltTab.active && !event.isAutoRepeat && event.key === Qt.Key_Alt)
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

    MouseArea
    {
        id: deck
        objectName: "altTabDeck"
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom; bottomMargin: 44; topMargin: 8 }
        width: parent.width
        clip: true
        acceptedButtons: Qt.NoButton
        onWheel: wheel =>
        {
            content.scroll(wheel.pixelDelta.y || wheel.pixelDelta.x, wheel.angleDelta.y || wheel.angleDelta.x);
            wheel.accepted = true;
        }

        Item
        {
            id: rail
            objectName: "altTabRail"
            width: deck.width
            height: deck.height
            x: (deck.width - content.cardWidth) / 2 - ServiceAltTab.selected * (content.cardWidth + content.cardSpacing)
            Glide on x { enabled: Config.animationsEnabled && ServiceAltTab.presented && content.positioned; duration: Theme.animationDurationControl }

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
                    x: index * (width + content.cardSpacing)
                    scale: selected ? 1 : 0.94
                    Glide on scale { enabled: Config.animationsEnabled && ServiceAltTab.presented && content.positioned; duration: Theme.animationDurationControl }

                    AltTabCard
                    {
                        anchors { fill: parent; margins: 3 }
                        windowData: card.modelData
                        selected: card.selected
                        hovered: area.containsMouse
                        pressed: area.pressed
                    }

                    MouseArea
                    {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked:
                        {
                            if (card.selected) ServiceAltTab.confirm();
                            else ServiceAltTab.select(card.index);
                        }
                        onWheel: wheel => wheel.accepted = false
                    }

                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.title || modelData.app_id
                    Accessible.selected: selected
                    Accessible.onPressAction: ServiceAltTab.select(index)
                }
            }
        }
    }

    Rectangle
    {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        width: Math.min(parent.width, information.implicitWidth + 32)
        height: 30
        radius: 15
        color: Theme.colorSolid
        Row
        {
            id: information
            anchors.centerIn: parent
            spacing: 12

            ShellText
            {
                id: hint
                width: Math.min(implicitWidth, Math.max(0, content.width - counter.width - 56))
                label: Tr.tr("altTab.hint")
                color: Theme.text2
                size: 11
            }
            ShellText
            {
                id: counter
                label: (ServiceAltTab.selected + 1) + " / " + ServiceAltTab.windows.length
                color: Theme.text1
                size: 11
                font.family: Theme.fontMono
            }
        }
    }
}
