pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"

Flickable
{
    id: settingsPage

    property string title: ""
    property string subtitle: ""
    readonly property bool active: activity.active

    RenderActivity { id: activity; target: settingsPage }

    default property alias content: column.data
    property alias header: fixedControls.data
    readonly property bool hasHeader: fixedControls.children.length > 0
    readonly property real headerHeight: hasHeader ? fixedHeader.height : 0

    clip: true
    contentWidth: width
    contentHeight: column.y + column.implicitHeight + 36
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    function resetScroll()
    {
        scroll.stop();
        cancelFlick();
        contentY = 0;
    }

    WheelHandler
    {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event =>
        {
            const delta = Config.scrollDelta(event.pixelDelta.y, event.angleDelta.y);
            const from = scroll.running ? scroll.to : settingsPage.contentY;
            const target = Math.max(0, Math.min(settingsPage.contentHeight - settingsPage.height, from - delta));

            scroll.stop();
            if (!Config.animationsEnabled || event.pixelDelta.y !== 0) settingsPage.contentY = target;
            else { scroll.to = target; scroll.start(); }

            event.accepted = true;
        }
    }

    Component.onCompleted:
    {
        if (!Config.animationsFluid) return;
        Qt.callLater(() =>
        {
            let order = 0;
            for (const child of column.children)
                if (typeof child.enter === "function") child.enter(order++);
        });
    }

    NumberAnimation
    {
        id: scroll
        target: settingsPage
        property: "contentY"
        duration: 320
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easingEmphasized
    }

    component Heading: Column
    {
        width: parent.width
        spacing: 6

        ShellText
        {
            label: settingsPage.title
            size: 24
            color: Theme.text1
            font.bold: true
        }
        ShellText
        {
            width: parent.width
            label: settingsPage.subtitle
            size: 12
            color: Theme.text3
            wrapMode: Text.Wrap
        }
    }

    Column
    {
        id: column

        x: 32
        y: settingsPage.hasHeader ? settingsPage.headerHeight + 6 : 28
        width: Math.max(0, settingsPage.width - 64)
        spacing: 22

        Heading { visible: !settingsPage.hasHeader }
    }

    Item
    {
        id: fixedHeader
        parent: settingsPage
        width: parent.width
        height: fixedControls.y + fixedControls.implicitHeight + 16
        visible: settingsPage.hasHeader
        z: 10

        Rectangle { anchors.fill: parent; color: Theme.settingsColorBackground }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true }
        Heading
        {
            id: fixedHeading
            x: 32; y: 28
            width: Math.max(0, parent.width - 64)
        }
        Column
        {
            id: fixedControls
            x: 32
            y: fixedHeading.y + fixedHeading.implicitHeight + 10
            width: Math.max(0, parent.width - 64)
            spacing: 6
        }
    }
}
