import QtQuick
import Quickshell.Widgets

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"

Rectangle
{
    id: launcherContent

    readonly property int  maxRows: Math.max(3, Math.min(12, Config.launcherRows))
    readonly property real rowH: Theme.launcherRow
    readonly property real footerH: 30
    readonly property real chrome: Theme.launcherPadding * 2 + Theme.launcherSearch + Theme.launcherSpacing + footerH

    readonly property int  rows: Math.min(apps.length, maxRows)
    readonly property real listH: apps.length > 0 ? rows * rowH : rowH * 2

    readonly property real fullHeight: chrome + maxRows * rowH

    property int selectedID: 0
    readonly property string query: input.text.trim().toLocaleLowerCase()
    readonly property var    apps: ServiceApplications.search(query)

    property bool instant: true
    onAppsChanged:
    {
        instant = true;
        mouseMode = false;
        selectedID = 0;
        list.contentY = 0;
        Qt.callLater(() => launcherContent.instant = false);
    }

    property bool introDone: false
    Timer { interval: 600; running: true; onTriggered: launcherContent.introDone = true }

    implicitHeight: chrome + listH

    radius: Theme.launcherRadius
    color: Theme.colorSolid
    border.color: Theme.colorHairline
    border.width: Theme.borderWidth
    clip: true

    function hide() { OverlayState.hide("launcher") }

    function reveal(i)
    {
        const top = i * rowH;
        const from = scroll.running ? scroll.to : list.contentY;
        let target = from;
        if (top < from) target = top;
        else if (top + rowH > from + list.height) target = top + rowH - list.height;
        scrollTo(target);
    }
    function scrollTo(target)
    {
        target = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), target));
        scroll.stop();
        if (!Config.animationsEnabled) { list.contentY = target; return; }
        scroll.to = target;
        scroll.start();
    }

    function move(offset)
    {
        if (apps.length === 0) return;
        mouseMode = false;
        const next = selectedID + offset;
        selectedID = Math.max(0, Math.min(apps.length - 1, next));
        reveal(selectedID);
    }

    property point pointer: Qt.point(NaN, NaN)

    property bool mouseMode: false
    function pointerMoved(item, x, y)
    {
        const p = item.mapToItem(null, x, y);
        const fresh = isNaN(pointer.x);
        const moved = fresh || Math.abs(p.x - pointer.x) > 0.5 || Math.abs(p.y - pointer.y) > 0.5;
        pointer = p;

        if (moved && !fresh) mouseMode = true;
        return moved && !fresh;
    }
    function launchSelected()
    {
        if (selectedID < 0 || selectedID >= apps.length) return;
        ServiceApplications.launchEntry(apps[selectedID]);
        hide();
    }

    function selectAtPointer()
    {
        if (!mouseMode || !listHover.hovered || apps.length === 0) return;
        const point = launcherContent.mapToItem(list, listHover.point.position.x, listHover.point.position.y);
        if (point.x < 0 || point.x >= list.width || point.y < 0 || point.y >= list.height) return;
        const contentPoint = list.mapToItem(list.contentItem, point.x, point.y);
        const index = list.indexAt(contentPoint.x, contentPoint.y);
        if (index >= 0) selectedID = index;
    }

    HoverHandler
    {
        id: listHover
        onPointChanged:
        {
            if (launcherContent.pointerMoved(launcherContent, point.position.x, point.position.y))
                launcherContent.selectAtPointer();
        }
    }

    function escapeHtml(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
    function marked(name)
    {
        const text = String(name || "");
        const at = query.length > 0 ? text.toLocaleLowerCase().indexOf(query) : -1;
        if (at < 0) return escapeHtml(text);
        return escapeHtml(text.slice(0, at)) + "<b>" + escapeHtml(text.slice(at, at + query.length)) + "</b>" + escapeHtml(text.slice(at + query.length));
    }

    NumberAnimation
    {
        id: scroll
        target: list
        property: "contentY"
        duration: 260
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easingEmphasized
    }

    Rectangle
    {
        id: search

        x: Theme.launcherPadding
        y: Theme.launcherPadding
        width: parent.width - Theme.launcherPadding * 2
        height: Theme.launcherSearch

        radius: Theme.radiusLarge
        color: Theme.colorField
        border.width: 1
        border.color: input.activeFocus ? Theme.accentAlpha(0.32) : "transparent"

        ShellIcon
        {
            id: searchIcon

            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            icon: Icon.search
            size: 16
            opacity: 0.8
        }

        TextInput
        {
            id: input

            anchors
            {
                left: searchIcon.right
                right: tail.left
                leftMargin: 12
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }

            focus: true
            color: Theme.text1
            selectionColor: Theme.colorSelection
            selectedTextColor: Theme.text1
            font.family: Theme.fontText
            font.pixelSize: Math.round(16 * Config.themeScale)
            selectByMouse: true
            clip: true

            Component.onCompleted: forceActiveFocus()
            onAccepted: launcherContent.launchSelected()

            Keys.onPressed: function(event)
            {
                const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;

                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J)))
                    launcherContent.move(1);
                else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K)))
                    launcherContent.move(-1);
                else if (event.key === Qt.Key_PageDown) launcherContent.move(launcherContent.maxRows);
                else if (event.key === Qt.Key_PageUp)   launcherContent.move(-launcherContent.maxRows);
                else if (ctrl && event.key === Qt.Key_U) input.text = "";

                else if (event.key === Qt.Key_Escape)   { if (input.text !== "") input.text = ""; else launcherContent.hide(); }
                else return;
                event.accepted = true;
            }

            ShellText
            {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                label: Tr.tr("launcher.searchApplications")
                size: 16
                color: Theme.text4
            }
        }

        Row
        {
            id: tail

            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8

            ShellText
            {
                anchors.verticalCenter: parent.verticalCenter
                label: launcherContent.query !== "" ? String(launcherContent.apps.length) : ""
                size: 12
                color: Theme.text3
                font.family: Theme.fontMono
            }

            Rectangle
            {
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: 13
                visible: opacity > 0.01
                opacity: input.text !== "" ? 1 : 0
                Smooth on opacity {}

                color: clearArea.pressed ? Theme.colorPressed : clearArea.containsMouse ? Theme.colorHover : "transparent"
                scale: clearArea.containsMouse ? 1.1 : 1
                Spring on scale {}

                ShellIcon { anchors.centerIn: parent; icon: Icon.close; size: 12; zoom: 1.1 }

                MouseArea
                {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { input.text = ""; input.forceActiveFocus(); }
                }
            }
        }
    }

    ListView
    {
        id: list

        x: Theme.launcherPadding
        y: search.y + search.height + Theme.launcherSpacing
        width: parent.width - Theme.launcherPadding * 2
        height: Math.max(0, launcherContent.height - y - launcherContent.footerH - Theme.launcherPadding)

        onContentYChanged: launcherContent.selectAtPointer()

        model: launcherContent.apps
        currentIndex: launcherContent.selectedID
        clip: true

        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2400

        highlightFollowsCurrentItem: false
        highlight: Rectangle
        {
            width: list.width
            height: launcherContent.rowH
            radius: Theme.radiusLarge
            color: Theme.colorCurrent

            y: list.currentItem ? list.currentItem.y : 0
            Glide on y { enabled: Config.animationsEnabled && !launcherContent.instant && !launcherContent.mouseMode; duration: 240 }
        }

        WheelHandler
        {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: event =>
            {
                const delta = Config.scrollDelta(event.pixelDelta.y, event.angleDelta.y);
                if (delta === 0) return;

                launcherContent.mouseMode = true;
                launcherContent.selectAtPointer();

                const from = scroll.running ? scroll.to : list.contentY;
                const target = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), from - delta));
                if (event.pixelDelta.y !== 0) { scroll.stop(); list.contentY = target; }
                else launcherContent.scrollTo(target);

                event.accepted = true;
            }
        }

        delegate: Item
        {
            id: row

            required property var modelData
            required property int index

            readonly property bool selected: index === launcherContent.selectedID

            width: list.width
            height: launcherContent.rowH

            property real rise: launcherContent.introDone || !Config.animationsFluid || index >= launcherContent.maxRows ? 1 : 0
            opacity: rise
            transform: Translate { y: (1 - row.rise) * 10 }
            Component.onCompleted: if (rise < 1) intro.start()
            SequentialAnimation
            {
                id: intro
                PauseAnimation { duration: 60 + row.index * 28 }
                NumberAnimation { target: row; property: "rise"; to: 1; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
            }

            IconImage
            {
                id: appIcon

                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                width: 32
                height: 32
                source: ServiceApplications.iconSource(row.modelData.icon)
                mipmap: true

                scale: row.selected ? 1 : 0.9
                Glide on scale { duration: 220 }
            }

            Column
            {
                anchors
                {
                    left: appIcon.right
                    leftMargin: 12
                    right: enter.left
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                spacing: 1

                ShellText
                {
                    width: parent.width
                    label: launcherContent.marked(row.modelData.name)
                    textFormat: Text.StyledText
                    size: 14
                    color: row.selected ? Theme.text1 : Theme.text2
                    Tint on color {}
                }
            }

            Rectangle
            {
                id: enter

                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width: enterText.implicitWidth + 14
                height: 20
                radius: 6
                color: Theme.colorField
                border.color: Theme.settingsColorLine
                border.width: 1

                opacity: row.selected ? 1 : 0
                Smooth on opacity { duration: 160 }

                ShellText { id: enterText; anchors.centerIn: parent; label: "↵"; size: 11; color: Theme.text3 }
            }

            MouseArea
            {
                id: rowArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: { launcherContent.selectedID = row.index; launcherContent.launchSelected(); }
            }
        }

        Column
        {
            anchors.centerIn: parent
            visible: launcherContent.apps.length === 0
            spacing: 10

            ShellIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: Icon.search; size: 28; opacity: 0.35 }
            ShellText
            {
                anchors.horizontalCenter: parent.horizontalCenter
                label: launcherContent.query !== "" ? Tr.tr("launcher.noAppsMatch").arg(input.text.trim()) : Tr.tr("launcher.noApplications")
                size: 13
                color: Theme.text3
            }
        }
    }

    Item
    {
        x: Theme.launcherPadding
        y: launcherContent.height - Theme.launcherPadding - height
        width: parent.width - Theme.launcherPadding * 2
        height: launcherContent.footerH

        Rectangle { width: parent.width; height: 1; color: Theme.settingsColorLine }

        ShellText
        {
            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter; verticalCenterOffset: 2 }
            label: input.text !== "" ? "↑ ↓  select    ↵  open    Esc  clear" : "↑ ↓  select    ↵  open    Esc  close"
            size: 11
            color: Theme.text4
        }
        ShellText
        {
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter; verticalCenterOffset: 2 }
            label: launcherContent.apps.length + (launcherContent.apps.length === 1 ? " app" : " apps")
            size: 11
            color: Theme.text4
        }
    }
}
