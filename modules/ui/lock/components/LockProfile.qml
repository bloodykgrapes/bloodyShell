import QtQuick
import Quickshell.Widgets

import "../../../common"
import "../../../core"
import "../../../services"

Column
{
    objectName: "lockProfile"
    visible: Config.lockAvatar || Config.lockName
    spacing: 14

    Item
    {
        visible: Config.lockAvatar
        width: parent.width
        height: avatar.height
        LockShadow { target: avatar }
        ClippingRectangle
        {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 88
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Theme.lockSurfaceEdge
            LockSurface { anchors.fill: parent; radius: avatar.radius; edge: false }
            Image
            {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                source: Icon.user
                width: Math.round(avatar.width * 0.42)
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
            }
            Image
            {
                id: face
                anchors.fill: parent
                source: ServiceAppearance.fileUrl(ServiceUser.avatar)
                sourceSize: Qt.size(208, 208)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
        }
    }
    ShellText
    {
        visible: Config.lockName
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        label: ServiceUser.fullName || ServiceUser.user
        size: 20
        wrapMode: Text.Wrap
        maximumLineCount: 2
        color: Theme.lockText1
        font.weight: Font.DemiBold
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: LockTextShadow {}
    }
}
