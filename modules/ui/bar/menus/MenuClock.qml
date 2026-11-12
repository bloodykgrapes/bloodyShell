pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../../animations"
import "../../../common"
import "../../../core"

Menu
{
    id: menuClock

    implicitWidth: 320
    spacing: 8
    activeFocusOnTab: true

    readonly property var en: Tr.locale
    readonly property int weekStart: Qt.locale().firstDayOfWeek % 7
    property int offset: 0
    readonly property date today: clock.date
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property var cells: datesFor(month)

    function capital(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s }
    function datesFor(date)
    {
        const lead = (date.getDay() - weekStart + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
        {
            const d = new Date(date.getFullYear(), date.getMonth(), 1 - lead + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === date.getMonth(),
                today: d.toDateString() === today.toDateString(),
                label: d.toLocaleDateString(en, "dddd d MMMM yyyy")
            });
        }
        return out;
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Keys.onLeftPressed: offset--
    Keys.onRightPressed: offset++
    Keys.onPressed: event =>
    {
        if (event.key === Qt.Key_PageUp) offset--;
        else if (event.key === Qt.Key_PageDown) offset++;
        else if (event.key === Qt.Key_Home) offset = 0;
        else return;
        event.accepted = true;
    }

    RevealSection
    {
        shown: menuClock.presented
        order: 0

        Rectangle
        {
            width: parent.width
            height: Math.max(96, summary.implicitHeight + 28)
            radius: 18
            color: Theme.colorCurrent
            Tint on color {}

            Rectangle
            {
                id: dateBadge
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                width: 64
                height: 64
                radius: 22
                color: Theme.colorAccent
                Tint on color {}
                ShellText
                {
                    anchors.centerIn: parent
                    label: String(menuClock.today.getDate())
                    size: 28
                    font.weight: Font.DemiBold
                    color: Theme.lightForeground(dateBadge.color) ? "#ffffff" : "#000000"
                    Tint on color {}
                }
            }
            Column
            {
                id: summary
                anchors { left: dateBadge.right; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 4
                ShellText
                {
                    width: parent.width
                    label: menuClock.capital(menuClock.today.toLocaleDateString(menuClock.en, "dddd"))
                    size: 16
                    color: Theme.text1
                    font.weight: Font.DemiBold
                }
                ShellText
                {
                    width: parent.width
                    label: menuClock.capital(menuClock.today.toLocaleDateString(menuClock.en, "MMMM yyyy"))
                    size: 12
                    color: Theme.text2
                }
            }
            Accessible.role: Accessible.StaticText
            Accessible.name: menuClock.today.toLocaleDateString(menuClock.en, "dddd d MMMM yyyy")
        }
    }

    RevealSection
    {
        shown: menuClock.presented
        order: 1

        Rectangle
        {
            width: parent.width
            height: monthContent.implicitHeight + 24
            radius: 18
            color: Theme.colorField
            Tint on color {}

            Column
            {
                id: monthContent
                x: 12; y: 12
                width: parent.width - 24
                spacing: 8

                Row
                {
                    width: parent.width
                    height: 32
                    spacing: 8
                    ActionButton
                    {
                        objectName: "calendarPrevious"
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tr.tr("menu.clock.previous")
                        icon: Icon.chevronLeft
                        iconOnly: true
                        onClicked: menuClock.offset--
                    }
                    ShellText
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 72
                        label: menuClock.capital(menuClock.en.standaloneMonthName(menuClock.month.getMonth(), Locale.LongFormat)) + " " + menuClock.month.getFullYear()
                        horizontalAlignment: Text.AlignHCenter
                        size: 13
                        color: Theme.text1
                        font.weight: Font.Medium
                    }
                    ActionButton
                    {
                        objectName: "calendarNext"
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tr.tr("menu.clock.next")
                        icon: Icon.chevronRight
                        iconOnly: true
                        onClicked: menuClock.offset++
                    }
                }

                Item
                {
                    id: deck
                    objectName: "calendarDeck"
                    width: parent.width
                    height: currentGrid.implicitHeight
                    clip: true
                    property int previousOffset: 0
                    property int displayedOffset: 0
                    property int direction: 1
                    property real progress: 1

                    function change()
                    {
                        transition.stop();
                        previousOffset = displayedOffset;
                        displayedOffset = menuClock.offset;
                        direction = displayedOffset >= previousOffset ? 1 : -1;
                        if (Config.animationsEnabled) transition.restart();
                        else progress = 1;
                    }
                    Connections
                    {
                        target: menuClock
                        function onOffsetChanged() { deck.change() }
                    }
                    Connections
                    {
                        target: Config
                        function onAnimationsEnabledChanged()
                        {
                            if (Config.animationsEnabled) return;
                            transition.stop();
                            deck.progress = 1;
                        }
                    }
                    NumberAnimation
                    {
                        id: transition
                        target: deck
                        property: "progress"
                        from: 0; to: 1
                        duration: Theme.animationDurationControl
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.easingEmphasized
                    }
                    DayGrid
                    {
                        width: parent.width
                        dates: menuClock.datesFor(new Date(menuClock.today.getFullYear(), menuClock.today.getMonth() + deck.previousOffset, 1))
                        visible: deck.progress < 1
                        opacity: 1 - deck.progress
                        x: Config.animationsFluid ? -deck.direction * 16 * deck.progress : 0
                    }
                    DayGrid
                    {
                        id: currentGrid
                        width: parent.width
                        dates: menuClock.cells
                        opacity: deck.progress
                        x: Config.animationsFluid ? deck.direction * 16 * (1 - deck.progress) : 0
                    }
                }
                ActionButton
                {
                    objectName: "calendarToday"
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.tr("menu.clock.today")
                    enabled: menuClock.offset !== 0
                    onClicked: menuClock.offset = 0
                }
            }
        }
    }

    component DayGrid: Grid
    {
        id: grid
        required property var dates
        columns: 7
        readonly property real cell: width / 7

        Repeater
        {
            model: 7
            ShellText
            {
                required property int index
                width: grid.cell
                height: 24
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                label: menuClock.en.dayName((menuClock.weekStart + index) % 7, Locale.NarrowFormat)
                size: 10
                color: Theme.text3
            }
        }
        Repeater
        {
            model: grid.dates
            Item
            {
                id: day
                required property var modelData
                width: grid.cell
                height: Math.max(34, 28)

                Rectangle
                {
                    id: dayFill
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 4, parent.height - 4)
                    height: width
                    radius: width / 2
                    color: day.modelData.today ? Theme.colorAccent : "transparent"
                    Tint on color {}
                }
                ShellText
                {
                    anchors.centerIn: parent
                    label: String(day.modelData.day)
                    size: 11
                    color: day.modelData.today ? (Theme.lightForeground(dayFill.color) ? "#ffffff" : "#000000")
                        : day.modelData.inMonth ? Theme.text1 : Theme.text4
                    font.weight: day.modelData.today ? Font.DemiBold : Font.Normal
                    Tint on color {}
                }
                Accessible.role: Accessible.StaticText
                Accessible.name: modelData.label
                Accessible.description: modelData.today ? Tr.tr("menu.clock.today") : ""
            }
        }
    }

    property real wheelRest: 0
    WheelHandler
    {
        target: null
        onWheel: event =>
        {
            menuClock.wheelRest += event.angleDelta.y;
            const steps = Math.trunc(menuClock.wheelRest / 120);
            if (steps !== 0)
            {
                menuClock.wheelRest -= steps * 120;
                menuClock.offset -= steps;
            }
            event.accepted = true;
        }
    }
}
