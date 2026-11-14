pragma ComponentBehavior: Bound

import QtQuick
import "." as Common

import "../animations"
import "../core"

Common.InteractiveControl
{
    id: tabRow

    property var options: []
    property var current
    signal selected(var value)

    readonly property int selectedIndex: options.findIndex(option => option.value === current)
    readonly property real inset: 4
    spacing: 4
    readonly property real tabWidth: Math.max(0, (width - inset * 2 - Math.max(0, options.length - 1) * spacing) / Math.max(1, options.length))
    property bool settled: false

    implicitWidth: options.length * 160
    implicitHeight: 44
    width: parent ? parent.width : implicitWidth
    activeFocusOnTab: enabled && options.length > 0
    Component.onCompleted: Qt.callLater(() => settled = true)

    function selectIndex(index, reason)
    {
        if (!enabled || options.length === 0) return;
        focusFor(reason);
        selected(options[Math.max(0, Math.min(options.length - 1, index))].value);
    }
    function move(offset) { selectIndex(selectedIndex < 0 ? 0 : selectedIndex + offset, Qt.TabFocusReason); }

    Keys.onLeftPressed: event => { move(-1); event.accepted = true }
    Keys.onRightPressed: event => { move(1); event.accepted = true }
    Keys.onPressed: event =>
    {
        if (event.key === Qt.Key_Home) selectIndex(0, Qt.TabFocusReason);
        else if (event.key === Qt.Key_End) selectIndex(options.length - 1, Qt.TabFocusReason);
        else return;
        event.accepted = true;
    }
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) selectIndex(Math.max(0, selectedIndex), Qt.TabFocusReason); event.accepted = true }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) selectIndex(Math.max(0, selectedIndex), Qt.TabFocusReason); event.accepted = true }

    background: Rectangle { radius: Theme.radiusLarge; color: Theme.colorField }

    Rectangle
    {
        objectName: "tabIndicator"
        visible: tabRow.selectedIndex >= 0
        x: tabRow.inset + Math.max(0, tabRow.selectedIndex) * (tabRow.tabWidth + tabRow.spacing)
        y: tabRow.inset
        width: tabRow.tabWidth
        height: tabRow.height - tabRow.inset * 2
        radius: Theme.radiusLarge - tabRow.inset
        color: tabRow.visualFocus ? Theme.colorHoverStrong : Theme.accentShell ? Theme.colorSelection : Theme.colorRaised
        Glide on x { enabled: tabRow.settled && Config.animationsEnabled }
        Tint on color {}
    }

    Row
    {
        x: tabRow.inset; y: tabRow.inset
        spacing: tabRow.spacing

        Repeater
        {
            model: tabRow.options

            Common.InteractiveControl
            {
                id: tab
                required property var modelData
                required property int index
                readonly property bool isCurrent: index === tabRow.selectedIndex
                readonly property int count: Math.max(0, Number(modelData.badge) || 0)

                objectName: "tab-" + modelData.value
                width: tabRow.tabWidth
                height: tabRow.height - tabRow.inset * 2
                scale: pointer.pressed ? 0.97 : 1
                Spring on scale {}

                background: Rectangle
                {
                    radius: Theme.radiusLarge - tabRow.inset
                    color: pointer.pressed ? Theme.colorPressed : Theme.colorHover
                    opacity: !tab.isCurrent && (tab.hovered || pointer.pressed) ? 1 : 0
                    Smooth on opacity {}
                }

                Row
                {
                    anchors.centerIn: parent
                    spacing: 6
                    ShellText
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, Math.min(implicitWidth, tab.width - 20 - (counter.visible ? counter.width + parent.spacing : 0)))
                        label: String(tab.modelData.label)
                        size: 12
                        font.weight: tab.isCurrent ? Font.DemiBold : Font.Medium
                        color: tab.isCurrent ? Theme.text1 : Theme.text2
                        Tint on color {}
                    }
                    Rectangle
                    {
                        id: counter
                        visible: tab.count > 0
                        width: Math.max(18, countText.implicitWidth + 8)
                        height: 18
                        radius: 9
                        color: Theme.colorAccent
                        ShellText { id: countText; anchors.centerIn: parent; label: tab.count > 99 ? "99+" : String(tab.count); size: 10; color: Theme.onAccent }
                    }
                }

                MouseArea
                {
                    id: pointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tabRow.selectIndex(tab.index, Qt.MouseFocusReason)
                }

                Accessible.role: Accessible.PageTab
                Accessible.name: String(modelData.label)
                Accessible.checkable: true
                Accessible.checked: isCurrent
                Accessible.onPressAction: tabRow.selectIndex(index, Qt.TabFocusReason)
            }
        }
    }

    Accessible.role: Accessible.PageTabList
}
