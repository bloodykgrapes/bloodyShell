pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

import "../../../../common"
import "../../../../core"

ClippingRectangle
{
    id: sample
    objectName: "shellSurfacePreview"

    required property Item backdrop

    readonly property int mode: ShellMaterial.mode
    readonly property string materialName: Registry.surfaceOptions.find(option => option.value === mode)?.label ?? ""

    radius: Math.min(Theme.menuRadius, height / 2)
    color: "transparent"
    contentInsideBorder: false

    Loader
    {
        anchors.fill: parent
        active: sample.mode === Enums.SurfaceBlur && GraphicsInfo.api !== GraphicsInfo.Software

        sourceComponent: Item
        {
            ShaderEffectSource
            {
                id: behindMenu
                visible: false
                sourceItem: sample.backdrop
                sourceRect: ShellMaterial.boundsIn(sample, sample.backdrop)
                textureSize: Qt.size(Math.max(1, Math.ceil(sample.width / 2)),
                    Math.max(1, Math.ceil(sample.height / 2)))
            }
            MultiEffect
            {
                anchors.fill: parent
                source: behindMenu
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 24
                blur: 0.30 + 0.70 * ShellMaterial.blurStrength
            }
        }
    }

    ShellSurface
    {
        anchors.fill: parent
        radius: sample.radius
        baseColor: Theme.frameColor
        border.width: Theme.panelBorderWidth
        border.color: Theme.colorPanelEdge
    }

    Row
    {
        anchors.centerIn: parent
        spacing: 14

        Rectangle
        {
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: width
            radius: Theme.radiusMedium
            color: Theme.controlColorActive
            ShellIcon { anchors.centerIn: parent; icon: Icon.settingsSurfaces; size: 22 }
        }
        Column
        {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            ShellText { label: Tr.tr("settings.appearance.shellSurface"); size: 16; font.weight: Font.DemiBold }
            ShellText { label: sample.materialName; color: Theme.text3; size: 13 }
        }
    }
}
