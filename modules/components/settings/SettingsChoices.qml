pragma ComponentBehavior: Bound

import QtQuick

import ".."
import "../../core"

Item
{
    id: settingsChoices

    property var options: []
    property var current
    property bool wrap: false

    signal selected(var value)

    function valueOf(option) { return option !== null && typeof option === "object" ? option.value : option }
    function labelOf(option) { return String(option !== null && typeof option === "object" ? option.label : option) }

    readonly property int selectedIndex: options.findIndex(option => String(valueOf(option)) === String(current))
    readonly property real inset: 4
    readonly property real segmentHeight: 28
    readonly property color selectedColor: Theme.accentShell
        ? Qt.hsla(Math.max(0, Theme.accent.hslHue), Theme.accent.hslSaturation, Theme.light ? 0.26 : 0.72, 1)
        : Theme.text1
    readonly property color selectedTextColor: Theme.lightForeground(selectedColor) ? "#ffffff" : "#000000"

    implicitWidth: wrap ? 400 : segments.implicitWidth + inset * 2
    implicitHeight: (wrap ? flow.implicitHeight : segmentHeight) + inset * 2
    width: wrap && parent ? parent.width : implicitWidth
    height: implicitHeight
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: true

    function move(offset)
    {
        if (options.length === 0) return;
        const index = selectedIndex < 0 ? 0 : Math.max(0, Math.min(options.length - 1, selectedIndex + offset));
        selected(valueOf(options[index]));
    }

    Keys.onRightPressed: event => { move(1); event.accepted = true }
    Keys.onLeftPressed: event => { move(-1); event.accepted = true }
    Keys.onPressed: event =>
    {
        if (event.key === Qt.Key_Home && options.length) selected(valueOf(options[0]));
        else if (event.key === Qt.Key_End && options.length) selected(valueOf(options[options.length - 1]));
        else return;
        event.accepted = true;
    }

    Rectangle
    {
        id: pill

        readonly property var target: settingsChoices.selectedIndex >= 0 && settingsChoices.selectedIndex < segmentRepeater.count
            ? segmentRepeater.itemAt(settingsChoices.selectedIndex) : null
        property bool settled: false
        Component.onCompleted: Qt.callLater(() => pill.settled = true)

        visible: !settingsChoices.wrap && target !== null
        x: target ? segments.x + target.x : settingsChoices.inset
        y: settingsChoices.inset + (Config.animationsFluid && target && target.hovered ? -1 : 0)
        width: target ? target.width : 0
        height: settingsChoices.segmentHeight
        radius: Theme.radiusMedium - 2
        color: settingsChoices.selectedColor
        Tint on color {}

        scale: target && target.pressed ? 0.95 : 1
        Spring on scale {}
        Spring on x
        {
            enabled: Config.animationsEnabled && pill.settled
            curve: Config.animationsFluid ? [0.2, 1.15, 0.3, 1.0, 1.0, 1.0] : Theme.easingEmphasized
        }
        Glide on y { duration: Theme.animationDurationControl }
        Glide on width { enabled: Config.animationsEnabled && pill.settled }
    }

    Row
    {
        id: segments
        visible: !settingsChoices.wrap
        x: settingsChoices.inset
        y: settingsChoices.inset
        spacing: 2

        Repeater
        {
            id: segmentRepeater
            model: settingsChoices.wrap ? [] : settingsChoices.options
            delegate: option
        }
    }

    Flow
    {
        id: flow
        visible: settingsChoices.wrap
        x: settingsChoices.inset
        y: settingsChoices.inset
        width: Math.max(0, settingsChoices.width - settingsChoices.inset * 2)
        spacing: 4

        Repeater
        {
            model: settingsChoices.wrap ? settingsChoices.options : []
            delegate: option
        }
    }

    Component
    {
        id: option

        Item
        {
            id: segment
            required property var modelData
            readonly property bool hovered: area.containsMouse
            readonly property bool pressed: area.pressed
            readonly property bool isCurrent: String(settingsChoices.valueOf(modelData)) === String(settingsChoices.current)

            width: settingsChoices.wrap ? Math.min(text.implicitWidth + 24, flow.width) : text.implicitWidth + 24
            height: settingsChoices.segmentHeight
            Item
            {
                id: visual
                anchors.fill: parent
                scale: area.pressed ? 0.95 : Config.animationsFluid && area.containsMouse ? 1.025 : 1
                Spring on scale {}

                property real lift: Config.animationsFluid && area.containsMouse ? -1 : 0
                transform: Translate { y: visual.lift }
                Glide on lift { duration: Theme.animationDurationControl }

                Rectangle
                {
                    anchors.fill: parent
                    radius: Theme.radiusMedium - 2
                    color: area.pressed ? Theme.colorPressed : Theme.colorHoverStrong
                    opacity: !segment.isCurrent && (area.pressed || area.containsMouse) ? 1 : 0
                    Smooth on opacity {}
                    Tint on color {}
                }

                Rectangle
                {
                    anchors.fill: parent
                    radius: Theme.radiusMedium - 2
                    color: settingsChoices.selectedColor
                    visible: settingsChoices.wrap
                    opacity: segment.isCurrent ? 1 : 0
                    scale: Config.animationsFluid ? 0.9 + 0.1 * opacity : 1
                    Smooth on opacity { duration: Theme.animationDurationControl }
                    Tint on color {}
                }

                ShellText
                {
                    id: text
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - 20)
                    horizontalAlignment: Text.AlignHCenter
                    label: settingsChoices.labelOf(segment.modelData)
                    color: segment.isCurrent ? settingsChoices.selectedTextColor : Theme.text2
                    scale: area.pressed ? 0.96 : 1
                    Spring on scale {}
                    Tint on color {}
                }
            }

            MouseArea
            {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked:
                {
                    settingsChoices.forceActiveFocus();
                    settingsChoices.selected(settingsChoices.valueOf(segment.modelData));
                }
            }

            Accessible.role: Accessible.RadioButton
            Accessible.name: settingsChoices.labelOf(modelData)
            Accessible.checkable: true
            Accessible.checked: isCurrent
            Accessible.onPressAction: settingsChoices.selected(settingsChoices.valueOf(modelData))
        }
    }
}
