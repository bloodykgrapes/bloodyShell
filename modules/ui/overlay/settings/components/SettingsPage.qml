pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls

import "../../../../common"
import "../../../../core"
import "." as Parts

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
    readonly property int pagePadding: width < 640 ? 24 : 32

    clip: true
    contentWidth: width
    contentHeight: column.y + column.implicitHeight + pagePadding
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height

    Controls.ScrollBar.vertical: Parts.SettingsScrollBar
    {
        view: settingsPage
        topPadding: settingsPage.pagePadding
        bottomPadding: settingsPage.pagePadding
    }

    SmoothScroll { id: scroll; view: settingsPage }

    function resetScroll()
    {
        scroll.stop();
        cancelFlick();
        contentY = 0;
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

    component Heading: Column
    {
        width: parent.width
        spacing: 8

        ShellText
        {
            width: Math.max(0, parent.width - Theme.settingsControlHeight - 12)
            label: settingsPage.title
            wrapMode: Text.Wrap
            size: 24
            color: Theme.text1
            font.weight: Font.DemiBold
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

        x: settingsPage.pagePadding
        y: settingsPage.hasHeader ? settingsPage.headerHeight + 6 : 28
        width: Math.max(0, settingsPage.width - settingsPage.pagePadding * 2)
        spacing: Theme.settingsSectionGap

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
            x: settingsPage.pagePadding; y: 28
            width: Math.max(0, parent.width - settingsPage.pagePadding * 2)
        }
        Column
        {
            id: fixedControls
            x: settingsPage.pagePadding
            y: fixedHeading.y + fixedHeading.implicitHeight + 10
            width: Math.max(0, parent.width - settingsPage.pagePadding * 2)
            spacing: 6
        }
    }
}
