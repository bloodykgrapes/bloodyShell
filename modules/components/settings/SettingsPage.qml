import QtQuick

import ".."
import "../../core"

Flickable
{
    id: settingsPage

    property string title: ""
    property string subtitle: ""

    default property alias content: column.data

    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight + 64
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

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

    Column
    {
        id: column

        x: 32
        y: 28
        width: Math.max(0, settingsPage.width - 64)
        spacing: 22

        Column
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
    }
}
