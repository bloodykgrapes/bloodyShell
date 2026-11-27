import QtQuick
import Quickshell.Widgets

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"

Rectangle
{
    id: launcherContent
    objectName: "launcherContent"

    readonly property int  maxRows: Math.max(3, Math.min(14, Config.launcherMaxResults))
    readonly property real rowH: Theme.launcherRow
    readonly property real footerH: width < 440 ? 48 : 34
    readonly property real footerGap: Theme.launcherSpacing
    readonly property real rowSpacing: Theme.launcherSpacing / 2
    readonly property real listInset: 6
    readonly property real chrome: Theme.launcherPadding * 2 + Theme.launcherSearch + Theme.launcherSpacing + footerGap + footerH

    readonly property int  rows: Math.min(apps.length, maxRows)
    readonly property real listH: listInset * 2 + (apps.length > 0 ? rows * rowH + Math.max(0, rows - 1) * rowSpacing : rowH * 2)

    readonly property real fullHeight: chrome + listInset * 2 + maxRows * rowH + (maxRows - 1) * rowSpacing

    property int selectedID: 0
    readonly property string query: input.text.trim().toLocaleLowerCase()
    readonly property var    apps: ServiceApplications.search(query)

    property bool instant: true
    property real surfaceRadius: Theme.launcherRadius
    onAppsChanged:
    {
        instant = true;
        mouseMode = false;
        selectedID = 0;
        scroll.stop();
        list.contentY = 0;
        Qt.callLater(() => launcherContent.instant = false);
    }

    implicitHeight: chrome + listH

    radius: surfaceRadius
    color: Theme.settingsColorBackground
    border.width: Theme.panelBorderWidth
    border.color: Theme.colorPanelEdge
    clip: true

    function hide() { OverlayState.hide("launcher") }

    function reveal(i)
    {
        const top = i * (rowH + rowSpacing);
        const from = scroll.running ? scroll.destination : list.contentY;
        let target = from;
        if (top < from) target = top;
        else if (top + rowH > from + list.height) target = top + rowH - list.height;
        scroll.scrollTo(target);
    }
    function move(offset)
    {
        if (apps.length === 0) return;
        mouseMode = false;
        const next = selectedID + offset;
        selectedID = Math.max(0, Math.min(apps.length - 1, next));
        reveal(selectedID);
    }

    Timer
    {
        id: resizeReveal
        interval: 0
        onTriggered: if (!launcherContent.instant && !launcherContent.mouseMode && launcherContent.apps.length > 0)
            launcherContent.reveal(launcherContent.selectedID)
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

    Rectangle
    {
        id: search

        x: Theme.launcherPadding
        y: Theme.launcherPadding
        width: parent.width - Theme.launcherPadding * 2
        height: Theme.launcherSearch

        radius: Theme.radiusLarge
        color: Theme.settingsColorSidebar
        border.width: 1
        border.color: input.activeFocus ? Theme.colorFocus : Theme.colorHairline
        Tint on border.color {}

        ShellIcon
        {
            id: searchIcon

            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            icon: Icon.search
            size: 20
            opacity: 0.85
        }

        TextInput
        {
            id: input
            objectName: "launcherSearchInput"

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
            font.pixelSize: 14
            selectByMouse: true
            clip: true
            Accessible.name: Tr.tr("launcher.searchApplications")

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
                width: parent.width
                visible: input.text === ""
                label: Tr.tr("launcher.searchApplications")
                size: 14
                color: Theme.text3
            }
        }

        Row
        {
            id: tail

            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8

            Rectangle
            {
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 24
                radius: 7
                visible: input.text === ""
                color: Theme.colorField
                border.width: 1
                border.color: Theme.settingsColorLine
                ShellText { anchors.centerIn: parent; label: "Esc"; size: 10; color: Theme.text3 }
            }

            Button
            {
                objectName: "launcherClear"
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                visible: opacity > 0.01
                enabled: input.text !== ""
                opacity: input.text !== "" ? 1 : 0
                Smooth on opacity {}
                color: "transparent"
                text: Tr.tr("launcher.clearSearch")
                icon: Icon.close
                iconOnly: true
                hoverScale: 1.04
                activeFocusOnTab: false
                onClicked: { input.text = ""; input.forceActiveFocus(Qt.MouseFocusReason); }
            }
        }
    }

    Rectangle
    {
        id: results
        objectName: "launcherResultsPanel"
        x: Theme.launcherPadding
        y: search.y + search.height + Theme.launcherSpacing
        width: parent.width - Theme.launcherPadding * 2
        height: Math.max(0, launcherContent.height - y - launcherContent.footerH - launcherContent.footerGap - Theme.launcherPadding)
        radius: Theme.radiusLarge + 2
        color: Theme.settingsColorCard
        border.width: 1
        border.color: Theme.settingsColorLine

        ListView
        {
            id: list
            objectName: "launcherResults"
            anchors { fill: parent; margins: launcherContent.listInset }
            spacing: launcherContent.rowSpacing

            onContentYChanged: launcherContent.selectAtPointer()
            onHeightChanged: resizeReveal.restart()

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
                radius: Theme.radiusLarge - 3
                color: Theme.accentShell ? Theme.accentAlpha(0.22) : Theme.inkAlpha(0.1)
                border.width: 1
                border.color: Theme.accentShell ? Theme.accentAlpha(0.16) : Theme.colorHairline

                y: list.currentItem ? list.currentItem.y : 0
                Glide on y { enabled: Config.animationsEnabled && !launcherContent.instant; duration: 240 }
            }

            SmoothScroll
            {
                id: scroll
                view: list
                onScrolled:
                {
                    launcherContent.mouseMode = true;
                    launcherContent.selectAtPointer();
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

                Rectangle
                {
                    anchors.fill: parent
                    radius: Theme.radiusLarge - 3
                    color: Theme.colorPressed
                    opacity: rowArea.pressed ? 1 : 0
                    Smooth on opacity { duration: 80 }
                }

                Rectangle
                {
                    id: appIcon
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 40
                    height: 40
                    radius: 11
                    color: Theme.colorField
                    scale: rowArea.pressed ? 0.94 : row.selected ? 1.03 : 1
                    Spring on scale {}
                    IconImage
                    {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        source: ServiceApplications.iconSource(row.modelData.icon)
                        mipmap: true
                    }
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
                        objectName: "launcherResultName"
                        width: parent.width
                        label: launcherContent.marked(row.modelData.name)
                        textFormat: Text.StyledText
                        size: 13
                        font.weight: row.selected ? Font.DemiBold : Font.Medium
                        color: row.selected ? Theme.text1 : Theme.text2
                        Tint on color {}
                    }
                }

                Rectangle
                {
                    id: enter

                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 30
                    height: 24
                    radius: 7
                    color: Theme.colorField
                    border.color: Theme.settingsColorLine
                    border.width: 1

                    opacity: row.selected ? 1 : 0
                    Smooth on opacity { duration: 160 }

                    ShellText { anchors.centerIn: parent; label: "↵"; size: 12; color: Theme.text2 }
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
                width: Math.max(0, parent.width - 32)
                visible: launcherContent.apps.length === 0
                spacing: 10

                ShellIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: Icon.search; size: 28; opacity: 0.35 }
                ShellText
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    label: launcherContent.query !== "" ? Tr.tr("launcher.noAppsMatch").arg(input.text.trim()) : Tr.tr("launcher.noApplications")
                    size: 12
                    color: Theme.text3
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
            }
        }
    }

    Item
    {
        x: Theme.launcherPadding
        y: launcherContent.height - Theme.launcherPadding - height
        width: parent.width - Theme.launcherPadding * 2
        height: launcherContent.footerH

        ShellText
        {
            x: 6
            y: launcherContent.width < 440 ? 0 : Math.round((parent.height - height) / 2) + 2
            width: launcherContent.width < 440 ? parent.width - 12 : Math.max(0, resultCount.x - x - 12)
            label: Tr.tr(launcherContent.query !== "" ? "launcher.navigationSearch" : "launcher.navigation")
            size: 11
            color: Theme.text3
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }
        Rectangle
        {
            id: resultCount
            x: parent.width - width - 6
            y: launcherContent.width < 440 ? parent.height - height : Math.round((parent.height - height) / 2) + 2
            width: Math.min(countLabel.implicitWidth + 16, parent.width * 0.35)
            height: 24
            radius: 8
            color: Theme.colorField
            ShellText
            {
                id: countLabel
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                label: Tr.tr("launcher.count").arg(launcherContent.apps.length)
                size: 11
                color: Theme.text3
            }
        }
    }
}
