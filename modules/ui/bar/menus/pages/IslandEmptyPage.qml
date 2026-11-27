import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Item
{
    id: emptyPage
    objectName: "islandEmptyPage"

    property string pageTitle: ""
    property string pageIcon: ""
    property string pageText: ""

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 184

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.menuControlRadius
        color: Theme.menuControlBackground
        Tint on color {}
    }

    Column
    {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 300)
        spacing: 9

        Rectangle
        {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 46
            height: 46
            radius: 16
            color: Theme.colorField
            ShellIcon { anchors.centerIn: parent; icon: emptyPage.pageIcon; size: 22; opacity: 0.72 }
        }
        ShellText
        {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            label: emptyPage.pageTitle
            size: 13
            font.weight: Font.DemiBold
            color: Theme.text1
        }
        ShellText
        {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            label: emptyPage.pageText
            size: 11
            color: Theme.text3
        }
    }
}
