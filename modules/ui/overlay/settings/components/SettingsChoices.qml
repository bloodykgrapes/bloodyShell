pragma ComponentBehavior: Bound

import QtQuick

import "../../../../animations"
import "../../../../common"
import "../../../../core"

Item
{
    id: settingsChoices

    property var options: []
    property var current
    property bool wrap: false
    readonly property var optionWidths:
    {
        // advanceWidth() does not register changes to the metrics' font.
        optionMetrics.font;
        return options.map(option => Math.ceil(optionMetrics.advanceWidth(labelOf(option))) + 24);
    }
    readonly property real preferredWidth: optionWidths.reduce((width, optionWidth) => width + optionWidth, 0) + Math.max(0, options.length - 1) * 2 + inset * 2
    readonly property bool flowing: wrap || preferredWidth > width

    FontMetrics { id: optionMetrics; font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.DemiBold }

    signal selected(var value)

    function valueOf(option) { return option !== null && typeof option === "object" ? option.value : option }
    function labelOf(option) { return String(option !== null && typeof option === "object" ? option.label : option) }

    readonly property int selectedIndex: options.findIndex(option => String(valueOf(option)) === String(current))
    readonly property real inset: 4
    readonly property real segmentHeight: Theme.settingsControlHeight - inset * 2
    readonly property color selectedColor: Theme.accentShell ? Theme.colorSelection : Theme.colorRaised

    implicitWidth: wrap ? 400 : preferredWidth
    implicitHeight: (flowing ? flow.implicitHeight : segmentHeight) + inset * 2
    width: Theme.controlWidth(settingsChoices, implicitWidth)
    height: implicitHeight
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: enabled && options.length > 0

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
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.colorField
    }

    Rectangle
    {
        id: pill

        readonly property var target: settingsChoices.selectedIndex >= 0 && settingsChoices.selectedIndex < segmentRepeater.count
            ? segmentRepeater.itemAt(settingsChoices.selectedIndex) : null
        property bool settled: false
        Component.onCompleted: Qt.callLater(() => pill.settled = true)

        visible: !settingsChoices.flowing && target !== null
        x: target ? segments.x + target.x : settingsChoices.inset
        y: settingsChoices.inset
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
        Glide on width { enabled: Config.animationsEnabled && pill.settled }
    }

    Row
    {
        id: segments
        visible: !settingsChoices.flowing
        x: settingsChoices.inset
        y: settingsChoices.inset
        spacing: 2

        Repeater
        {
            id: segmentRepeater
            model: settingsChoices.flowing ? [] : settingsChoices.options
            delegate: option
        }
    }

    Flow
    {
        id: flow
        visible: settingsChoices.flowing
        x: settingsChoices.inset
        y: settingsChoices.inset
        width: Math.max(0, settingsChoices.width - settingsChoices.inset * 2)
        spacing: 4

        Repeater
        {
            model: settingsChoices.flowing ? settingsChoices.options : []
            delegate: option
        }
    }

    Component
    {
        id: option

        Item
        {
            id: segment
            required property int index
            required property var modelData
            readonly property bool pressed: area.pressed
            readonly property bool isCurrent: String(settingsChoices.valueOf(modelData)) === String(settingsChoices.current)

            readonly property real preferredWidth: settingsChoices.optionWidths[index] || 24
            width: settingsChoices.flowing ? Math.min(preferredWidth, flow.width) : preferredWidth
            height: settingsChoices.segmentHeight
            Item
            {
                anchors.fill: parent
                scale: area.pressed ? 0.97 : 1
                Spring on scale {}

                Rectangle
                {
                    anchors.fill: parent
                    radius: Theme.radiusMedium - 2
                    color: area.pressed ? Theme.colorPressed : Theme.colorHover
                    opacity: !segment.isCurrent && (area.pressed || area.containsMouse) ? 1 : 0
                    Smooth on opacity {}
                    Tint on color {}
                }

                Rectangle
                {
                    anchors.fill: parent
                    radius: Theme.radiusMedium - 2
                    color: settingsChoices.selectedColor
                    visible: settingsChoices.flowing
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
                    color: segment.isCurrent ? Theme.text1 : Theme.text2
                    font.weight: segment.isCurrent ? Font.DemiBold : Font.Normal
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
                    settingsChoices.forceActiveFocus(Qt.MouseFocusReason);
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
