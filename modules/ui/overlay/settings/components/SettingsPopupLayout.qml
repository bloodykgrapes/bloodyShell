pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls

import "../../../../common"
import "../../../../core"

Item
{
    id: layout

    property string title: ""
    property string icon: ""
    property string footerText: ""
    property bool showCloseButton: false
    property string errorText: ""
    property bool fillContent: false
    property real spacing: 14
    property real bodyInset: 0
    signal closeRequested()
    property alias header: headerColumn.data
    property alias actions: actionRow.data
    property alias contentSpacing: bodyColumn.spacing
    default property alias content: bodyColumn.data
    readonly property real bodyHeight: Math.max(0, viewport.height - bodyInset * 2 - (errorText !== "" ? failure.implicitHeight + spacing : 0))
    readonly property bool hasContent: fillContent || bodyColumn.implicitHeight > 0 || errorText !== ""
    readonly property real chromeHeight:
    {
        const heights = [title !== "" ? toolbar.implicitHeight : 0, headerColumn.implicitHeight,
            footer.implicitHeight].filter(height => height > 0);
        return heights.reduce((sum, height) => sum + height, 0)
            + Math.max(0, heights.length + (hasContent ? 1 : 0) - 1) * spacing;
    }

    implicitHeight: chromeHeight + viewport.contentHeight
    Accessible.role: Accessible.Dialog
    Accessible.name: title

    function revealBodyItem(item)
    {
        if (!viewport.interactive) return;
        const top = item.mapToItem(viewport.contentItem, 0, 0).y - bodyInset;
        const bottom = top + item.height + bodyInset * 2;
        if (top < viewport.contentY) scroll.scrollTo(top, false);
        else if (bottom > viewport.contentY + viewport.height) scroll.scrollTo(bottom - viewport.height, false);
    }

    onErrorTextChanged: if (errorText !== "") revealError.restart()
    Timer
    {
        id: revealError
        interval: 0
        onTriggered: if (layout.errorText !== "") scroll.scrollTo(viewport.contentHeight - viewport.height)
    }

    Column
    {
        width: parent.width
        spacing: layout.spacing

        Item
        {
            id: toolbar
            width: parent.width
            implicitHeight: Math.max(heading.implicitHeight, layout.icon !== "" ? 36 : 0, layout.showCloseButton ? 28 : 0)
            height: implicitHeight
            visible: layout.title !== ""

            Rectangle
            {
                id: badge
                width: 36; height: 36; radius: 11
                anchors.verticalCenter: parent.verticalCenter
                visible: layout.icon !== ""
                color: Theme.colorField
                ShellIcon { anchors.centerIn: parent; icon: layout.icon; size: 20 }
            }
            ShellText
            {
                id: heading
                objectName: "settingsPopupTitle"
                x: layout.icon !== "" ? badge.width + 12 : 0
                width: Math.max(0, (layout.showCloseButton ? close.x - 12 : parent.width) - x)
                anchors.verticalCenter: parent.verticalCenter
                label: layout.title
                size: Theme.popupTitleSize
                font.weight: Font.DemiBold
                color: Theme.text1
                wrapMode: Text.Wrap
            }
            Button
            {
                iconOnly: true
                id: close
                objectName: "settingsPopupClose"
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 28; height: 28; radius: 9
                visible: layout.showCloseButton
                icon: Icon.close
                iconSize: 12
                text: Tr.tr("common.close")
                onClicked: layout.closeRequested()
            }
        }
        Column
        {
            id: headerColumn
            width: parent.width
            spacing: layout.spacing
            visible: implicitHeight > 0
        }
        Flickable
        {
            id: viewport
            objectName: "settingsPopupBody"
            width: parent.width
            height: Math.max(0, layout.height - layout.chromeHeight)
            visible: layout.hasContent
            contentWidth: width
            contentHeight: layout.hasContent ? contentColumn.implicitHeight + layout.bodyInset * 2 : 0
            interactive: contentHeight > height + 0.5
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            clip: true

            SmoothScroll { id: scroll; view: viewport }
            Controls.ScrollBar.vertical: SettingsScrollbar
            {
                view: viewport
                topPadding: 4
                bottomPadding: 4
            }
            Column
            {
                id: contentColumn
                x: layout.bodyInset
                y: layout.bodyInset
                width: Math.max(0, viewport.width - layout.bodyInset * 2 - (viewport.interactive ? 12 : 0))
                spacing: layout.spacing
                Column
                {
                    id: bodyColumn
                    width: parent.width
                    spacing: 1
                    visible: implicitHeight > 0
                }
                Rectangle
                {
                    id: failure
                    width: parent.width
                    implicitHeight: failureText.implicitHeight + 20
                    height: implicitHeight
                    visible: layout.errorText !== ""
                    radius: 12
                    color: Qt.rgba(Theme.colorCritical.r, Theme.colorCritical.g, Theme.colorCritical.b, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(Theme.colorCritical.r, Theme.colorCritical.g, Theme.colorCritical.b, 0.16)
                    Rectangle
                    {
                        x: 12; y: 12
                        width: 16; height: 16; radius: 8
                        color: "transparent"
                        border.width: 1; border.color: Theme.colorCritical
                        ShellText { anchors.centerIn: parent; label: "!"; size: 11; color: Theme.colorCritical; font.bold: true }
                    }
                    ShellText
                    {
                        id: failureText
                        objectName: "settingsPopupError"
                        x: 40; y: 10
                        width: Math.max(0, parent.width - x - 12)
                        label: layout.errorText
                        color: Theme.colorCritical
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
        Item
        {
            id: footer
            objectName: "settingsPopupActions"
            width: parent.width
            implicitHeight: actionRow.implicitHeight > 0 || layout.footerText !== "" ? Math.max(actionRow.implicitHeight, footerLabel.implicitHeight) + 14 : 0
            height: implicitHeight
            visible: implicitHeight > 0
            Rectangle { width: parent.width; height: 1; color: Theme.settingsColorLine }
            ShellText
            {
                id: footerLabel
                x: 0; y: 14 + Math.round((actionRow.implicitHeight - height) / 2)
                width: Math.max(0, actionRow.x - 16)
                label: layout.footerText
                size: 11
                color: Theme.text3
            }
            Row
            {
                id: actionRow
                y: 14
                anchors.right: parent.right
                spacing: 10
            }
        }
    }
}
