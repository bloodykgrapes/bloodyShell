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
    property string pageIcon: ""
    property string backTitle: ""
    readonly property bool active: activity.active
    readonly property bool hasBack: backTitle !== ""
    readonly property real backOffset: hasBack ? 38 : 0
    signal backRequested()
    signal revealRequested(var item)

    RenderActivity { id: activity; target: settingsPage }

    default property alias content: column.data
    property alias header: fixedControls.data
    readonly property bool hasHeader: fixedControls.children.length > 0
    readonly property real headerHeight: fixedHeader.height
    readonly property int pagePadding: width < 640 ? 22 : 28

    clip: true
    contentWidth: width
    contentHeight: column.y + column.implicitHeight + pagePadding
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height

    Controls.ScrollBar.vertical: Parts.SettingsScrollbar
    {
        view: settingsPage
        topPadding: settingsPage.headerHeight + 12
        bottomPadding: settingsPage.pagePadding
    }

    SmoothScroll { id: scroll; view: settingsPage }

    function resetScroll()
    {
        scroll.stop();
        cancelFlick();
        contentY = 0;
    }

    function revealItem(item)
    {
        const top = item.mapToItem(contentItem, 0, 0).y;
        const bottom = top + item.height;
        if (top < contentY + headerHeight) scroll.scrollTo(top - headerHeight - 6);
        else if (bottom > contentY + height) scroll.scrollTo(bottom - height + 6);
    }

    component Heading: Row
    {
        width: parent.width
        spacing: 12

        Rectangle
        {
            id: iconTile
            visible: settingsPage.pageIcon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: width
            radius: Theme.radiusMedium
            color: Theme.controlColorActive
            ShellIcon { anchors.centerIn: parent; icon: settingsPage.pageIcon; size: 22 }
        }
        Column
        {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - 44 - (iconTile.visible ? iconTile.width + parent.spacing : 0))
            spacing: 4

            ShellText
            {
                width: parent.width
                label: settingsPage.title
                wrapMode: Text.Wrap
                size: 20
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
    }

    Column
    {
        id: column

        x: settingsPage.pagePadding
        y: settingsPage.headerHeight + 16
        width: Math.max(0, settingsPage.width - settingsPage.pagePadding * 2)
        spacing: Theme.settingsSectionGap
    }

    Item
    {
        id: fixedHeader
        objectName: "settingsPageHeader"
        parent: settingsPage
        width: parent.width
        height: fixedControls.y + (settingsPage.hasHeader ? fixedControls.implicitHeight + 12 : 0) + 16
        z: 10

        Rectangle
        {
            anchors.fill: parent
            topRightRadius: Theme.settingsRadius - 1
            color: Theme.settingsColorBackground
        }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true }
        Button
        {
            x: settingsPage.pagePadding
            y: 14
            visible: settingsPage.hasBack
            compact: true
            icon: Icon.chevronLeft
            text: settingsPage.backTitle
            maximumWidth: Math.max(0, parent.width - settingsPage.pagePadding * 2)
            onClicked: settingsPage.backRequested()
        }
        Heading
        {
            id: fixedHeading
            x: settingsPage.pagePadding; y: 20 + settingsPage.backOffset
            width: Math.max(0, parent.width - settingsPage.pagePadding * 2)
        }
        Column
        {
            id: fixedControls
            x: settingsPage.pagePadding
            y: fixedHeading.y + fixedHeading.implicitHeight + (settingsPage.hasHeader ? 12 : 0)
            width: Math.max(0, parent.width - settingsPage.pagePadding * 2)
            spacing: 6
        }
        Rectangle
        {
            x: settingsPage.pagePadding
            y: parent.height - 1
            width: Math.max(0, parent.width - settingsPage.pagePadding * 2)
            height: 1
            color: Theme.settingsColorLine
        }
    }
}
