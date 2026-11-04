pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

import "../../components"
import "../../components/bar"
import "../../core"
import "../../services"

Item
{
    id: menuTray

    readonly property int  maxColumns: 5
    readonly property real cell: Math.round(36 * Config.themeScale)
    readonly property real pad: Math.round(10 * Config.themeScale)
    readonly property real rowH: Math.round(30 * Config.themeScale)
    readonly property real maxListH: Math.round(320 * Config.themeScale)
    readonly property real contextW: Math.round(230 * Config.themeScale)

    readonly property var entries: Array.from(SystemTray.items.values).filter(it => it.status !== 0)

    function titleOf(item) { return item ? (item.tooltipTitle || item.title || item.id || "") : "" }

    property var hovered: null
    readonly property string caption: hovered ? titleOf(hovered)
        : hasContext ? titleOf(contextItem)
        : entries.length + (entries.length === 1 ? " app" : " apps")

    readonly property var  contextItem: MenuState.trayContextItem
    readonly property bool hasContext: !!contextItem && contextItem.hasMenu

    property var stack: []

    property var level: null

    function updateLevel() { level = stack.length > 0 ? stack[stack.length - 1] : (contextItem && contextItem.hasMenu ? contextItem.menu : null) }

    onStackChanged: updateLevel()
    onHasContextChanged: updateLevel()
    onContextItemChanged: { stack = []; updateLevel(); }
    Component.onCompleted: updateLevel()

    function toggleContext(item)
    {
        MenuState.trayContextItem = (MenuState.trayContextItem === item) ? null : item;
    }

    function activate(entry)
    {
        if (entry.hasChildren)
        {
            stack = stack.concat([entry]);
            ctx.slide(1);
            return;
        }

        entry.triggered();
        MenuState.close();
    }

    function back()
    {
        stack = stack.slice(0, -1);
        ctx.slide(-1);
    }

    readonly property real gridH: entries.length > 0 ? grid.height : Math.max(empty.implicitHeight, cell)

    implicitWidth: Math.max(Math.max(grid.width, empty.implicitWidth, cell * 3) + pad * 2,
                            hasContext ? contextW : 0)
    implicitHeight: pad + gridH + 4 + label.height + (hasContext ? 6 + ctx.height : 0) + pad

    Grid
    {
        id: grid

        visible: menuTray.entries.length > 0
        x: Math.round((menuTray.width - width) / 2)
        y: menuTray.pad

        columns: Math.max(1, Math.min(menuTray.maxColumns, menuTray.entries.length))
        spacing: 4

        Repeater
        {
            model: menuTray.entries

            Item
            {
                id: cell

                required property var modelData

                width: menuTray.cell
                height: menuTray.cell

                TrayButton
                {
                    id: icon

                    anchors.fill: parent
                    trayItem: cell.modelData
                    iconSize: Math.round(22 * Config.themeScale)
                    active: MenuState.trayContextItem === cell.modelData

                    onLaunched: MenuState.close()
                    onContextRequested: menuTray.toggleContext(cell.modelData)
                    onContainsMouseChanged: menuTray.hovered = containsMouse ? cell.modelData : (menuTray.hovered === cell.modelData ? null : menuTray.hovered)
                }
            }
        }
    }

    ShellText
    {
        id: empty

        visible: menuTray.entries.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: menuTray.pad + (menuTray.cell - implicitHeight) / 2

        label: Tr.tr("menu.tray.noAppsInTray")
        color: Theme.text3
    }

    ShellText
    {
        id: label

        x: menuTray.pad
        y: menuTray.pad + menuTray.gridH + 4
        width: menuTray.width - menuTray.pad * 2
        height: Math.round(18 * Config.themeScale)
        visible: menuTray.entries.length > 0

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        label: menuTray.caption
        size: 11
        color: menuTray.hovered ? Theme.text1 : Theme.text3
        Tint on color {}
    }

    QsMenuOpener
    {
        id: opener
        menu: menuTray.level
    }

    Item
    {
        id: ctx

        x: menuTray.pad
        y: label.y + label.height + 6
        width: menuTray.width - menuTray.pad * 2
        height: 1 + 5 + menuTray.rowH + 4 + flick.height
        clip: true

        opacity: menuTray.hasContext ? 1 : 0
        visible: opacity > 0
        Smooth on opacity {}

        property real shift: 0
        function slide(direction)
        {
            if (!Config.animationsEnabled) return;
            slideIn.stop();
            shift = direction * 28;
            content.opacity = 0;
            slideIn.start();
        }
        ParallelAnimation
        {
            id: slideIn
            NumberAnimation { target: ctx; property: "shift"; to: 0; duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
            NumberAnimation { target: content; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.colorLine }

        Item
        {
            id: content

            width: parent.width
            height: parent.height
            transform: Translate { x: ctx.shift }

            Item
            {
                id: header

                y: 6
                width: parent.width
                height: menuTray.rowH

                ShellText
                {
                    visible: menuTray.stack.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    width: header.width - 16
                    label: menuTray.titleOf(menuTray.contextItem)
                    color: Theme.text2
                    font.bold: true
                }

                MouseArea
                {
                    id: backArea

                    visible: menuTray.stack.length > 0
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menuTray.back()

                    Rectangle
                    {
                        anchors.fill: parent
                        radius: Theme.barWidgetRadius
                        color: Theme.menuColorHover
                        opacity: backArea.containsMouse ? 1 : 0
                        Smooth on opacity {}
                    }

                    Row
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 6
                        spacing: 6

                        ShellIcon { anchors.verticalCenter: parent.verticalCenter; icon: Icon.chevronLeft; size: 12; opacity: 0.7 }
                        ShellText
                        {
                            anchors.verticalCenter: parent.verticalCenter
                            width: header.width - 40
                            label: menuTray.level && menuTray.level.text ? menuTray.level.text : ""
                            color: Theme.text1
                            font.bold: true
                        }
                    }
                }
            }

            Flickable
            {
                id: flick

                y: 6 + menuTray.rowH + 4
                width: parent.width
                height: Math.max(menuTray.rowH, Math.min(col.implicitHeight, menuTray.maxListH))

                contentHeight: col.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column
                {
                    id: col
                    width: flick.width

                    Repeater
                    {
                        model: opener.children

                        Item
                        {
                            id: row

                            required property var modelData

                            width: col.width
                            height: modelData.isSeparator ? 9 : menuTray.rowH

                            Rectangle
                            {
                                visible: row.modelData.isSeparator
                                anchors.centerIn: parent
                                width: parent.width - 12
                                height: 1
                                color: Theme.colorLine
                            }

                            Rectangle
                            {
                                visible: !row.modelData.isSeparator
                                anchors.fill: parent
                                radius: Theme.barWidgetRadius
                                color: Theme.menuColorHover
                                opacity: rowMouse.containsMouse && row.modelData.enabled ? 1 : 0
                                Smooth on opacity {}
                            }

                            Item
                            {
                                visible: !row.modelData.isSeparator
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                opacity: row.modelData.enabled ? 1 : 0.4

                                Item
                                {
                                    id: mark

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16

                                    ShellIcon
                                    {
                                        anchors.centerIn: parent
                                        visible: row.modelData.buttonType === 1 && row.modelData.checkState === Qt.Checked
                                        icon: Icon.check
                                        size: 13
                                    }
                                    Rectangle
                                    {
                                        anchors.centerIn: parent
                                        visible: row.modelData.buttonType === 2
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: row.modelData.checkState === Qt.Checked ? Theme.colorAccent : "transparent"
                                        border.color: Theme.text3
                                        border.width: row.modelData.checkState === Qt.Checked ? 0 : 1
                                    }

                                    Image
                                    {
                                        anchors.fill: parent
                                        visible: row.modelData.buttonType === 0 && row.modelData.icon !== ""
                                        source: visible ? ServiceApplications.trayIcon(row.modelData.icon, "") : ""
                                        sourceSize: Qt.size(32, 32)
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        mipmap: true
                                    }
                                }

                                ShellText
                                {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: mark.width + 8
                                    width: parent.width - mark.width - 8 - (arrow.visible ? 18 : 0)

                                    label: row.modelData.text
                                    color: Theme.text1
                                }

                                ShellIcon
                                {
                                    id: arrow

                                    visible: row.modelData.hasChildren
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    icon: Icon.chevronRight
                                    size: 12
                                    opacity: 0.6
                                }
                            }

                            MouseArea
                            {
                                id: rowMouse

                                anchors.fill: parent
                                enabled: !row.modelData.isSeparator && row.modelData.enabled
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: menuTray.activate(row.modelData)
                            }
                        }
                    }
                }
            }

            ShellText
            {
                visible: opener.children.values.length === 0
                x: 8
                y: 6 + menuTray.rowH + 4 + (menuTray.rowH - implicitHeight) / 2

                label: Tr.tr("menu.tray.noActions")
                color: Theme.text3
            }
        }
    }
}
