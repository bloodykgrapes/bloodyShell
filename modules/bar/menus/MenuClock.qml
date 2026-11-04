pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../components"
import "../../components/bar"
import "../../core"

Menu
{
    id: menuClock

    implicitWidth: 284

    readonly property var en: Tr.locale

    function capital(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s }
    readonly property int weekStart: Qt.locale().firstDayOfWeek % 7

    SystemClock { id: clock; precision: SystemClock.Minutes }

    property int offset: 0
    readonly property date today: clock.date
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)

    readonly property var cells:
    {
        const lead = (month.getDay() - weekStart + 7) % 7;
        const first = new Date(month.getFullYear(), month.getMonth(), 1 - lead);
        const out = [];
        for (let i = 0; i < 42; i++)
        {
            const d = new Date(first.getFullYear(), first.getMonth(), first.getDate() + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month.getMonth(),
                today: d.toDateString() === today.toDateString()
            });
        }
        return out;
    }

    Item
    {
        width: parent.width
        height: 58

        Column
        {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 2

            ShellText
            {
                label: menuClock.capital(menuClock.today.toLocaleDateString(menuClock.en, "dddd"))
                size: 11
                color: Theme.text3
            }
            ShellText
            {
                label: menuClock.today.toLocaleDateString(menuClock.en, "d MMMM yyyy")
                size: 17
                color: Theme.text1
            }
        }
    }

    MenuSeparator { }

    Item
    {
        width: parent.width
        height: 32

        ShellText
        {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }

            label: menuClock.capital(menuClock.en.standaloneMonthName(menuClock.month.getMonth(), Locale.LongFormat)) + " " + menuClock.month.getFullYear()
            size: 13
            color: Theme.text1
        }

        Row
        {
            anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
            spacing: 2

            Repeater
            {
                model: [
                    { icon: Icon.chevronLeft,  step: -1 },
                    { icon: "",                step: 0  },
                    { icon: Icon.chevronRight, step: 1  }
                ]

                Rectangle
                {
                    required property var modelData

                    visible: modelData.step !== 0 || menuClock.offset !== 0
                    width: modelData.step === 0 ? todayText.implicitWidth + 16 : 28
                    height: 28
                    radius: 14
                    color: navArea.pressed ? Theme.colorPressed : navArea.containsMouse ? Theme.colorHover : "transparent"

                    ShellIcon { anchors.centerIn: parent; icon: parent.modelData.icon; size: 14 }
                    ShellText
                    {
                        id: todayText
                        anchors.centerIn: parent
                        label: parent.modelData.step === 0 ? Tr.tr("menu.clock.today") : ""
                        size: 11
                    }

                    MouseArea
                    {
                        id: navArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menuClock.offset = parent.modelData.step === 0 ? 0 : menuClock.offset + parent.modelData.step
                    }
                }
            }
        }
    }

    Grid
    {
        id: grid

        columns: 7
        width: parent.width

        readonly property real cell: Math.floor(width / 7)

        Repeater
        {
            model: 7

            ShellText
            {
                required property int index
                width: grid.cell
                height: 22
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                label: menuClock.en.dayName((menuClock.weekStart + index) % 7, Locale.NarrowFormat)
                size: 10
                color: Theme.text3
            }
        }

        Repeater
        {
            model: menuClock.cells

            Item
            {
                required property var modelData

                width: grid.cell
                height: 30

                Rectangle
                {
                    anchors.centerIn: parent
                    width: 26; height: 26; radius: 13
                    color: parent.modelData.today ? Theme.colorAccent : "transparent"
                }

                ShellText
                {
                    anchors.centerIn: parent
                    label: String(parent.modelData.day)
                    size: 11
                    color: parent.modelData.today ? Theme.colorSolid
                        : parent.modelData.inMonth ? Theme.text2 : Theme.text4
                    font.weight: parent.modelData.today ? Font.DemiBold : Font.Normal
                }
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
            while (menuClock.wheelRest >= 120) { menuClock.offset--; menuClock.wheelRest -= 120 }
            while (menuClock.wheelRest <= -120) { menuClock.offset++; menuClock.wheelRest += 120 }
        }
    }
}
