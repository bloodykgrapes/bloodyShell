pragma ComponentBehavior: Bound

import QtQuick

import ".."
import "../../core"

Item
{
    id: settingsLayoutEditor

    property string zone: "bar1"
    property string heading: ""

    property bool picking: false

    readonly property var list:
    {
        const l = Config.barLayout;
        return l && Array.isArray(l[zone]) ? l[zone] : [];
    }

    readonly property var available:
    {
        const used = {};
        const l = Config.barLayout || {};
        for (const k in l)
            for (const id of l[k]) used[id] = true;
        if (used.user) used.system = true;
        return Object.keys(Registry.widgets).filter(id => !Registry.widgets[id].hidden && (id === "separator" || !used[id]));
    }

    function title(id) { return Registry.widgets[id] ? Registry.widgets[id].title : id }

    function commit(next) { Config.setLayout(zone, next) }

    readonly property real rowHeight: 36
    property int  dragIndex: -1
    property real dragY: 0
    readonly property int dropIndex: dragIndex < 0 ? -1 : Math.max(0, Math.min(list.length - 1, Math.round(dragY / rowHeight)))

    function slotOf(index)
    {
        if (dragIndex < 0 || index === dragIndex) return index;
        if (dragIndex < dropIndex && index > dragIndex && index <= dropIndex) return index - 1;
        if (dragIndex > dropIndex && index >= dropIndex && index < dragIndex) return index + 1;
        return index;
    }

    function drop()
    {
        const from = dragIndex, to = dropIndex;
        dragIndex = -1;
        if (from < 0 || to < 0 || from === to) return;
        const next = list.slice();
        const [item] = next.splice(from, 1);
        next.splice(to, 0, item);
        commit(next);
    }
    function remove(index)
    {
        const next = list.slice();
        next.splice(index, 1);
        commit(next);
    }
    function add(id)
    {
        commit(list.concat([id]));
        picking = false;
    }

    width: parent ? parent.width : 400
    height: col.implicitHeight

    SettingsTile { row: settingsLayoutEditor }

    Column
    {
        id: col
        width: parent.width

        Item
        {
            width: parent.width
            height: 44

            ShellText
            {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                label: settingsLayoutEditor.heading
                size: 13
                color: Theme.text1
            }
            ShellText
            {
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                label: settingsLayoutEditor.list.length === 0 ? Tr.tr("common.empty") : (settingsLayoutEditor.list.length === 1 ? Tr.tr("settings.widget") : Tr.tr("settings.widgets")).arg(settingsLayoutEditor.list.length)
                size: 11
                color: Theme.text3
            }
        }

        Item
        {
            id: rows
            width: col.width
            height: settingsLayoutEditor.list.length * settingsLayoutEditor.rowHeight

            Repeater
            {
                model: settingsLayoutEditor.list

                Item
                {
                    id: line

                    required property string modelData
                    required property int    index

                    readonly property bool dragging: settingsLayoutEditor.dragIndex === index

                    width: rows.width
                    height: settingsLayoutEditor.rowHeight
                    z: dragging ? 10 : 0

                    y: dragging ? settingsLayoutEditor.dragY : settingsLayoutEditor.slotOf(index) * settingsLayoutEditor.rowHeight
                    Glide on y { enabled: Config.animationsEnabled && !line.dragging && settingsLayoutEditor.dragIndex >= 0 }

                    scale: dragging ? 1.02 : 1
                    Spring on scale {}

                    Rectangle
                    {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        radius: Theme.radiusMedium
                        color: line.dragging ? Theme.colorHoverStrong : lineHover.hovered || grab.pressed ? Theme.colorHover : "transparent"
                        border.width: line.dragging ? 1 : 0
                        border.color: Theme.colorLine
                        Tint on color {}
                    }
                    HoverHandler { id: lineHover }

                    MouseArea
                    {
                        id: grab

                        property real startMouse: 0
                        property real startY: 0

                        anchors.fill: parent
                        cursorShape: line.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        preventStealing: true

                        onPressed: mouse =>
                        {
                            startMouse = mapToItem(rows, mouse.x, mouse.y).y;
                            startY = line.y;
                            settingsLayoutEditor.dragY = line.y;
                            settingsLayoutEditor.dragIndex = line.index;
                        }
                        onPositionChanged: mouse =>
                        {
                            if (!pressed) return;
                            const now = mapToItem(rows, mouse.x, mouse.y).y;
                            settingsLayoutEditor.dragY = Math.max(-settingsLayoutEditor.rowHeight / 2, Math.min(rows.height - settingsLayoutEditor.rowHeight / 2, startY + now - startMouse));
                        }
                        onReleased: settingsLayoutEditor.drop()
                        onCanceled: settingsLayoutEditor.dragIndex = -1
                    }

                    Grid
                    {
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        columns: 2
                        spacing: 3
                        opacity: lineHover.hovered || line.dragging ? 0.9 : 0.4
                        Smooth on opacity {}
                        Repeater { model: 6; Rectangle { width: 3; height: 3; radius: 1.5; color: Theme.text2 } }
                    }

                    ShellText
                    {
                        x: 34
                        width: 22
                        anchors.verticalCenter: parent.verticalCenter
                        label: (settingsLayoutEditor.slotOf(line.index) + (line.dragging ? settingsLayoutEditor.dropIndex - line.index : 0) + 1) + "."
                        color: Theme.text4
                        font.family: Theme.fontMono
                    }
                    ShellText
                    {
                        x: 58
                        anchors.verticalCenter: parent.verticalCenter
                        label: settingsLayoutEditor.title(line.modelData)
                        size: 13
                        color: line.dragging ? Theme.text1 : Theme.text2
                    }

                    SettingsIconButton
                    {
                        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        icon: Icon.close
                        visible: !line.dragging
                        onClicked: settingsLayoutEditor.remove(line.index)
                    }
                }
            }
        }

        Item
        {
            width: parent.width
            height: settingsLayoutEditor.picking ? pick.implicitHeight + 24 : 48
            clip: true

            Glide on height {}

            SettingsButton
            {
                visible: !settingsLayoutEditor.picking
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                icon: Icon.add
                text: Tr.tr("settings.addWidget")
                enabled: settingsLayoutEditor.available.length > 0
                onClicked: settingsLayoutEditor.picking = true
            }

            Flow
            {
                id: pick
                visible: settingsLayoutEditor.picking
                opacity: settingsLayoutEditor.picking ? 1 : 0
                Smooth on opacity { duration: 220 }
                x: 16
                y: 10
                width: parent.width - 32
                spacing: 6

                Repeater
                {
                    model: settingsLayoutEditor.picking ? settingsLayoutEditor.available : []

                    SettingsButton
                    {
                        required property string modelData
                        text: settingsLayoutEditor.title(modelData)
                        onClicked: settingsLayoutEditor.add(modelData)
                    }
                }

                SettingsButton { text: Tr.tr("common.cancel"); onClicked: settingsLayoutEditor.picking = false }
            }
        }
    }
}
