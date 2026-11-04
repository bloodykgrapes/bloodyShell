pragma ComponentBehavior: Bound

import QtQuick

import "../components"
import "../components/bar"
import "../core"
import "../services"

Item
{
    id: osdContent

    readonly property bool glassContent: Theme.blur

    property bool useB: false
    readonly property View front: useB ? viewB : viewA
    readonly property View back:  useB ? viewA : viewB

    implicitWidth: front.implicitWidth
    implicitHeight: front.implicitHeight
    width: implicitWidth
    height: implicitHeight

    readonly property bool clickable: front.snap.notification !== null

    readonly property real value: front.snap.value
    readonly property bool dim: front.snap.dim

    function snapshot()
    {
        const n = ServiceOSD.type === "notifications" ? ServiceOSD.currentNotification : null;
        return {
            type: ServiceOSD.type,
            icon: ServiceOSD.icon,
            text: ServiceOSD.text,
            detail: ServiceOSD.detail,
            context: ServiceOSD.context,
            value: ServiceOSD.value,
            dim: ServiceOSD.dim,
            notification: n,
            notificationIcon: n ? notificationIconOf(n) : ""
        };
    }
    function notificationIconOf(n) { return iconProbe.sourceOf(n) }

    function present()
    {
        const next = snapshot();

        if (!ServiceOSD.active)
        {
            back.shown = false;
            front.settle(next);
            front.shown = true;
            return;
        }

        const current = front.snap;
        const sameKind = current.type === next.type
            && (next.type !== "notifications" || current.notification === next.notification);
        if (sameKind)
        {
            front.snap = next;
            return;
        }

        back.settle(next);
        useB = !useB;
        front.shown = true;
        back.shown = false;
    }

    Connections
    {
        target: ServiceOSD

        function onPresentationRevisionChanged() { osdContent.present() }
        function onActiveChanged() { if (ServiceOSD.active && Config.animationsFluid) pop.restart() }
    }
    Component.onCompleted: if (ServiceOSD.active) present()

    NotificationIcon { id: iconProbe; visible: false }

    transformOrigin: Item.Center
    SequentialAnimation
    {
        id: pop

        NumberAnimation { target: osdContent; property: "scale"; to: 1.05; duration: 90;  easing.type: Easing.OutCubic }
        NumberAnimation { target: osdContent; property: "scale"; to: 1;    duration: 240; easing.type: Easing.OutBack }
    }

    View { id: viewA; shown: true; x: Math.round((osdContent.width - width) / 2); y: Math.round((osdContent.height - height) / 2) }
    View { id: viewB;              x: Math.round((osdContent.width - width) / 2); y: Math.round((osdContent.height - height) / 2) }

    MouseArea
    {
        anchors.fill: parent
        enabled: osdContent.clickable
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse =>
        {
            if (mouse.button === Qt.LeftButton) ServiceOSD.activateNotification();
            else ServiceOSD.dismissNotification();
        }
    }

    component View: Item
    {
        id: view

        property var  snap: ({ type: "", icon: "", text: "", detail: "", context: "", value: -1, dim: false, notification: null, notificationIcon: "" })
        property bool shown: false

        property bool live: true
        function settle(next)
        {
            live = false;
            snap = next;
            Qt.callLater(() => view.live = true);
        }

        readonly property bool isNotification: snap.type === "notifications"
        readonly property real maxTextWidth: isNotification ? 340 : 320

        readonly property real minValueWidth: Math.round(190 * Config.themeScale)
        implicitWidth: snap.value >= 0 ? Math.max(row.implicitWidth, minValueWidth) : row.implicitWidth
        implicitHeight: isNotification ? Math.max(row.implicitHeight, 48) + 15 : row.implicitHeight
        width: implicitWidth
        height: implicitHeight

        opacity: shown ? 1 : 0
        Appear on opacity {}
        visible: opacity > 0.01

        Row
        {
            id: row

            anchors.verticalCenter: parent.verticalCenter
            x: view.snap.value >= 0 ? 0 : Math.round((view.width - width) / 2)
            spacing: 12

            NotificationIcon
            {
                visible: view.isNotification && (view.snap.notification !== null || view.snap.notificationIcon !== "")
                anchors.verticalCenter: parent.verticalCenter
                n: view.snap.notification
                fixedSource: view.snap.notificationIcon
                size: 36
            }

            Item
            {
                visible: !view.isNotification && view.snap.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18

                Image
                {
                    anchors.fill: parent
                    source: view.snap.icon
                    sourceSize: Qt.size(36, 36)
                    fillMode: Image.PreserveAspectFit
                    opacity: view.snap.dim ? 0.5 : 1
                }
            }

            Column
            {
                visible: view.snap.context !== "" || view.snap.text !== "" || view.snap.detail !== ""
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                ShellText
                {
                    width: Math.min(implicitWidth, view.maxTextWidth)
                    label: view.snap.context
                    size: 10
                    color: Theme.text3
                }

                ShellText
                {
                    width: Math.min(implicitWidth, view.maxTextWidth)
                    label: view.snap.text
                    color: view.snap.dim ? Theme.text3 : Theme.text1
                    font.bold: view.snap.context !== "" || view.snap.detail !== ""
                }

                ShellText
                {
                    width: Math.min(implicitWidth, view.maxTextWidth)
                    label: view.snap.detail
                    size: 11
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
            }
        }
    }
}
