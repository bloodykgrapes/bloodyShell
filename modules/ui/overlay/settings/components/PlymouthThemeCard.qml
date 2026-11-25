pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Item
{
    id: tile
    required property var theme
    required property bool current
    required property bool selected
    required property bool loadArtwork
    required property bool busy
    required property bool applying
    required property bool canApply
    required property bool needsApply
    property string error: ""

    signal selectedTheme()
    signal applyRequested()
    signal revealRequested(Item action)

    height: card.height

    Controls.Button
    {
        id: card
        readonly property bool selected: tile.selected

        objectName: "plymouthTheme-" + tile.theme.id
        text: tile.theme.name
        width: tile.width
        enabled: !tile.applying
        padding: 6
        horizontalPadding: padding
        bottomPadding: 0
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        scale: down ? 0.98 : hovered ? 1.02 : 1
        Spring on scale {}

        onClicked:
        {
            tile.selectedTheme();
            Qt.callLater(() =>
            {
                if (tile.loadArtwork && apply.visible) tile.revealRequested(apply);
            });
        }
        Keys.onReturnPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }
        Keys.onEnterPressed: event => { if (!event.isAutoRepeat) clicked(); event.accepted = true }

        Accessible.role: Accessible.RadioButton
        Accessible.name: text
        Accessible.description: [tile.current ? Tr.tr("settings.plymouth.current").arg(text) : "", tile.theme.description || ""]
            .filter(part => part !== "").join(". ")
        Accessible.checkable: true
        Accessible.checked: selected
        Accessible.onPressAction: if (enabled) clicked()

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        background: Rectangle
        {
            radius: Theme.controlRadius
            color: card.down ? Theme.colorPressed : card.selected ? Theme.colorFieldFocus
                : card.hovered || card.visualFocus ? Theme.colorHoverStrong : Theme.colorField
            border.width: card.visualFocus ? 1 : 0
            border.color: Theme.text1
            Tint on color {}
        }
        contentItem: Column
        {
            PlymouthThemePreview
            {
                artwork: tile.theme.preview || ({})
                loadArtwork: tile.loadArtwork
            }
            Item
            {
                id: caption
                width: parent.width
                height: 38

                ShellText
                {
                    objectName: "plymouthThemeTitle"
                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                    anchors.right: check.visible ? check.left : parent.right
                    anchors.rightMargin: check.visible ? 6 : apply.visible ? apply.width + 8 : 4
                    label: card.text
                    size: Theme.settingsLabelSize
                    color: card.selected ? Theme.text1 : Theme.text2
                    font.weight: Font.Medium
                    Tint on color {}
                }
                ShellIcon
                {
                    id: check
                    objectName: "plymouthCurrentTheme"
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    anchors.rightMargin: apply.visible ? apply.width + 6 : 4
                    visible: tile.current
                    icon: Icon.check
                    size: 14
                }
            }
            ShellText
            {
                width: parent.width
                leftPadding: 4
                rightPadding: 4
                bottomPadding: visible ? 8 : 0
                label: tile.error
                color: Theme.colorCritical
                wrapMode: Text.Wrap
                size: 11
            }
        }
    }

    Button
    {
        id: apply
        objectName: "applyPlymouthTheme"
        x: tile.width - width - 6
        y: card.topPadding + caption.y + (caption.height - height) / 2
        height: 28
        primary: true
        visible: tile.selected && tile.needsApply
        enabled: tile.canApply && !tile.busy
        text: tile.applying ? Tr.tr("common.working") : Tr.tr("common.apply")
        Accessible.description: Tr.tr(tile.canApply ? "settings.plymouth.applyHint" : "settings.plymouth.authMissing")
        onClicked: tile.applyRequested()
    }
}
