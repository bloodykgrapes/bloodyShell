import QtQuick
import Quickshell

import "../../../common"
import "../../../core"
import "../../../services"

Item
{
    id: row

    required property var entry
    property int order: 0
    property int direction: 1
    property int revision: 0
    property bool presented: true
    property real reveal: 1
    signal triggered()

    function enter()
    {
        entrance.stop();
        if (!Config.animationsEnabled) { reveal = 1; return; }
        if (!presented) return;
        reveal = 0;
        entrance.start();
    }

    onEntryChanged: Qt.callLater(enter)
    onRevisionChanged: Qt.callLater(enter)
    onPresentedChanged: if (presented) Qt.callLater(enter); else entrance.stop()
    Component.onCompleted: enter()

    opacity: reveal
    transform: Translate { x: Config.animationsEnabled ? row.direction * (Config.animationsFluid ? 12 : 6) * (1 - row.reveal) : 0 }

    SequentialAnimation
    {
        id: entrance
        PauseAnimation { duration: Math.max(0, Math.min(row.order, 5)) * (Config.animationsFluid ? 24 : 10) }
        NumberAnimation { target: row; property: "reveal"; to: 1; duration: Config.animationsFluid ? 240 : 140; easing.type: Easing.OutCubic }
    }
    Connections
    {
        target: Config
        function onAnimationsEnabledChanged() { if (!Config.animationsEnabled) row.enter() }
    }

    readonly property bool separator: entry && entry.isSeparator
    readonly property bool checked: entry && entry.checkState === Qt.Checked
    readonly property bool checkable: entry && entry.buttonType !== QsMenuButtonType.None

    width: ListView.view ? ListView.view.rowWidth : parent ? parent.width : 200
    height: separator ? 9 : 30

    MenuSeparator { anchors.centerIn: parent; visible: row.separator }

    ActionButton
    {
        id: action
        objectName: "trayAction"
        anchors.fill: parent
        visible: !row.separator
        enabled: !!row.entry && row.entry.enabled
        color: "transparent"
        radius: Theme.radiusMedium
        hoverScale: 1.025
        Accessible.name: row.entry ? row.entry.text : ""
        Accessible.role: !row.checkable ? Accessible.MenuItem
            : row.entry.buttonType === QsMenuButtonType.RadioButton ? Accessible.RadioButton : Accessible.CheckBox
        Accessible.checkable: row.checkable
        Accessible.checked: row.checked
        onClicked: row.triggered()
        Keys.onRightPressed: event =>
        {
            if (row.entry && row.entry.hasChildren) row.triggered();
            else event.accepted = false;
        }

        Item
        {
            id: mark
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: width

            ShellIcon
            {
                anchors.centerIn: parent
                visible: row.entry && row.entry.buttonType === QsMenuButtonType.CheckBox && row.checked
                icon: Icon.check
                size: 13
            }
            Rectangle
            {
                anchors.centerIn: parent
                visible: row.entry && row.entry.buttonType === QsMenuButtonType.RadioButton
                width: 12; height: 12; radius: 6
                color: "transparent"
                border.width: row.checked ? 0 : 1
                border.color: Theme.text3
                Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.colorAccent; visible: row.checked }
            }
            Image
            {
                anchors.fill: parent
                visible: row.entry && !row.checkable && row.entry.icon !== ""
                source: visible ? ServiceApplications.trayIcon(row.entry.icon, "") : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }
        ShellText
        {
            anchors { left: mark.right; leftMargin: 10; right: arrow.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            label: row.entry ? row.entry.text : ""
            textFormat: Text.PlainText
            color: Theme.text1
        }
        ShellIcon
        {
            id: arrow
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            icon: row.entry && row.entry.hasChildren ? Icon.chevronRight : ""
            size: 12
            opacity: 0.6
        }
    }
}
