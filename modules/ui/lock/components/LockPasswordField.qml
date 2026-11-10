import QtQuick
import QtQuick.Shapes

import "../../../animations"
import "../../../common"
import "../../../core"

Item
{
    id: lockPasswordField

    property bool reveal: false
    readonly property alias text: input.text

    property bool busy: false
    property bool failed: false
    property bool closed: false
    signal submitted(string password)
    signal edited()

    function clear() { input.text = ""; reveal = false }
    function focusInput() { input.forceActiveFocus() }
    onClosedChanged: if (closed) clear()

    Connections
    {
        target: Config
        function onAnimationsEnabledChanged()
        {
            if (Config.animationsEnabled) return;
            for (let i = 0; i < dots.count; i++) dots.itemAt(i).show(true);
        }
    }

    height: 44

    readonly property int  padding: 18
    readonly property real dot: 12
    readonly property real dotStep: dot + 7
    readonly property real counterRoom: 30
    readonly property real dotsRoom: width - padding - buttons.width - 14 - counterRoom
    readonly property int  dotsMax: Math.max(4, Math.floor((dotsRoom + 7) / dotStep))
    readonly property int  length: input.text.length
    readonly property int  dotsShown: Math.min(length, dotsMax)

    property var shapes: []
    function updateShapes()
    {
        const count = Math.min(length, dotsMax);
        const next = shapes.slice(0, count);
        const usage = [0, 0, 0];
        for (const shape of next) usage[shape]++;
        while (next.length < count)
        {
            const previous = next.length > 0 ? next[next.length - 1] : -1;
            const available = [0, 1, 2].filter(shape => shape !== previous);
            const least = Math.min(...available.map(shape => usage[shape]));
            const choices = available.filter(shape => usage[shape] === least);
            const shape = choices[Math.floor(Math.random() * choices.length)];
            next.push(shape);
            usage[shape]++;
        }
        shapes = next;
    }
    onLengthChanged: updateShapes()
    onDotsMaxChanged: updateShapes()

    Rectangle
    {
        anchors.fill: parent
        radius: 14
        color: "transparent"
        LockShadow {}
        LockSurface { anchors.fill: parent; radius: parent.radius; edge: false }
        Rectangle
        {
            anchors.fill: parent
            radius: parent.radius
            color: input.activeFocus || lockPasswordField.reveal ? Theme.lockFocus : "transparent"
            border.width: 1
            border.color: lockPasswordField.failed ? Theme.colorCritical : input.activeFocus ? Theme.lockHighlight : Theme.lockSurfaceEdge
            Tint on color {}
            Tint on border.color {}
        }
    }

    TextInput
    {
        id: input
        objectName: "lockPasswordInput"
        anchors.fill: parent
        leftPadding: lockPasswordField.padding
        rightPadding: buttons.width + 16
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        focus: true
        opacity: lockPasswordField.reveal ? 1 : 0
        echoMode: lockPasswordField.reveal ? TextInput.Normal : TextInput.Password
        font.family: Theme.fontText
        font.pixelSize: Math.round(15 * Config.themeScale)
        color: Theme.lockText1
        selectionColor: Theme.lockSelection
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
        readOnly: lockPasswordField.busy || lockPasswordField.closed

        Component.onCompleted: forceActiveFocus()
        onAccepted: lockPasswordField.submitted(text)
        onTextEdited: lockPasswordField.edited()

        Keys.onPressed: event =>
        {
            if (event.key === Qt.Key_Escape || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Backspace))
            {
                input.text = "";
                event.accepted = true;
            }
        }
    }

    Item
    {
        x: lockPasswordField.padding
        width: lockPasswordField.dotsRoom + lockPasswordField.counterRoom
        height: parent.height
        visible: !lockPasswordField.reveal

        Repeater
        {
            id: dots
            model: lockPasswordField.dotsMax

            Item
            {
                id: dotItem
                required property int index
                readonly property bool on: index < lockPasswordField.dotsShown
                readonly property int  shape: lockPasswordField.shapes[index] !== undefined ? lockPasswordField.shapes[index] : 0
                readonly property real size: lockPasswordField.dot + 4
                x: index * lockPasswordField.dotStep - 2
                y: (parent.height - height) / 2
                width: size
                height: size

                scale: 0
                rotation: Config.animationsFluid ? -70 : 0
                opacity: 0
                visible: scale > 0.01
                function show(now)
                {
                    appear.stop(); leave.stop();
                    if (now || !Config.animationsEnabled) { scale = on ? 1 : 0; rotation = !on && Config.animationsFluid ? -70 : 0; opacity = on ? 1 : 0; return; }
                    (on ? appear : leave).start();
                }
                onOnChanged: show(false)
                Component.onCompleted: show(true)
                ParallelAnimation
                {
                    id: appear
                    NumberAnimation { target: dotItem; property: "scale"; to: 1; duration: Config.animationsFluid ? 360 : 180; easing.type: Config.animationsFluid ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.3 }
                    NumberAnimation { target: dotItem; property: "rotation"; to: 0; duration: Config.animationsFluid ? 420 : 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: dotItem; property: "opacity"; to: 1; duration: Config.animationsFluid ? 120 : 90 }
                }
                ParallelAnimation
                {
                    id: leave
                    NumberAnimation { target: dotItem; property: "scale"; to: 0; duration: Config.animationsFluid ? 180 : 120; easing.type: Easing.InCubic }
                    NumberAnimation { target: dotItem; property: "rotation"; to: Config.animationsFluid ? -70 : 0; duration: Config.animationsFluid ? 180 : 120; easing.type: Easing.InCubic }
                    NumberAnimation { target: dotItem; property: "opacity"; to: 0; duration: Config.animationsFluid ? 150 : 100 }
                }

                Rectangle
                {
                    visible: dotItem.shape < 2
                    anchors.centerIn: parent
                    width: dotItem.shape === 0 ? lockPasswordField.dot : lockPasswordField.dot * 0.94
                    height: width
                    radius: dotItem.shape === 0 ? width / 2 : width * 0.28
                    color: Theme.lockText1
                    antialiasing: true
                }

                Shape
                {
                    visible: dotItem.shape === 2
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath
                    {
                        fillColor: Theme.lockText1
                        strokeColor: "transparent"
                        strokeWidth: 0
                        startX: dotItem.size * 0.4136
                        startY: dotItem.size * 0.2112
                        PathQuad { controlX: dotItem.size * 0.5; controlY: dotItem.size * 0.06; x: dotItem.size * 0.5864; y: dotItem.size * 0.2112 }
                        PathLine { x: dotItem.size * 0.8936; y: dotItem.size * 0.7488 }
                        PathQuad { controlX: dotItem.size * 0.98; controlY: dotItem.size * 0.9; x: dotItem.size * 0.8072; y: dotItem.size * 0.9 }
                        PathLine { x: dotItem.size * 0.1928; y: dotItem.size * 0.9 }
                        PathQuad { controlX: dotItem.size * 0.02; controlY: dotItem.size * 0.9; x: dotItem.size * 0.1064; y: dotItem.size * 0.7488 }
                        PathLine { x: dotItem.size * 0.4136; y: dotItem.size * 0.2112 }
                    }
                }
            }
        }
        Rectangle
        {
            id: caret
            x: lockPasswordField.dotsShown * lockPasswordField.dotStep
            y: (parent.height - height) / 2
            width: 2
            height: lockPasswordField.dot + 10
            radius: 1
            color: Theme.lockHighlight
            visible: input.activeFocus && !lockPasswordField.busy && lockPasswordField.length <= lockPasswordField.dotsShown
            Behavior on x { enabled: Config.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            SequentialAnimation on opacity
            {
                running: caret.visible && Config.animationsEnabled
                onRunningChanged: if (!running) caret.opacity = 1
                loops: Animation.Infinite
                NumberAnimation { to: 0.15; duration: 500; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1;    duration: 500; easing.type: Easing.InOutQuad }
            }
        }

        ShellText
        {
            x: lockPasswordField.dotsShown * lockPasswordField.dotStep + 2
            anchors.verticalCenter: parent.verticalCenter
            visible: lockPasswordField.length > lockPasswordField.dotsShown
            label: "+" + (lockPasswordField.length - lockPasswordField.dotsShown)
            size: 12
            font.weight: Font.DemiBold
            color: Theme.lockText2
        }
    }

    Row
    {
        id: buttons
        anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
        spacing: 4

        Rectangle
        {
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 30; radius: eyeArea.containsMouse ? 9 : 15
            Behavior on radius { enabled: Config.animationsEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            color: eyeArea.pressed ? Theme.lockPressed : eyeArea.containsMouse ? Theme.lockHover : "transparent"
            Tint on color {}
            scale: eyeArea.pressed ? 0.9 : eyeArea.containsMouse ? 1.08 : 1
            Spring on scale {}
            Image
            {
                anchors.centerIn: parent
                source: lockPasswordField.reveal ? Icon.eyeOff : Icon.eye
                width: 14; height: 14; sourceSize: Qt.size(28, 28)
                opacity: lockPasswordField.reveal || eyeArea.containsMouse ? 1 : 0.6
            }
            MouseArea
            {
                id: eyeArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !lockPasswordField.busy && !lockPasswordField.closed
                cursorShape: Qt.PointingHandCursor
                onClicked: { lockPasswordField.reveal = !lockPasswordField.reveal; input.forceActiveFocus() }
            }
        }

        Rectangle
        {
            id: submit
            readonly property bool ready: !lockPasswordField.busy && input.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 34; radius: submitArea.containsMouse ? 10 : 17
            Behavior on radius { enabled: Config.animationsEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            color: lockPasswordField.busy ? Theme.lockStrong : ready ? Theme.lockHighlight : submitArea.pressed ? Theme.lockPressed : submitArea.containsMouse ? Theme.lockHover : Theme.lockStrong
            scale: submitArea.pressed ? 0.9 : submitArea.containsMouse ? 1.08 : 1
            Tint on color { duration: 160 }
            Spring on scale {}

            Image
            {
                anchors.centerIn: parent
                width: 14; height: 14
                sourceSize: Qt.size(28, 28)
                source: lockPasswordField.busy ? Icon.reload : submit.ready ? Qt.resolvedUrl("../../../../assets/icons/" + (Theme.lightForeground(Theme.lockHighlight) ? "light" : "dark") + "/chevron_right.svg") : Icon.chevronRight
                RotationAnimation on rotation
                {
                    running: lockPasswordField.visible && lockPasswordField.busy && Config.animationsEnabled
                    onRunningChanged: if (!running) rotation = 0
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 900
                }
                onSourceChanged: rotation = 0
            }
            MouseArea
            {
                id: submitArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !lockPasswordField.busy && !lockPasswordField.closed
                cursorShape: Qt.PointingHandCursor
                onClicked: lockPasswordField.submitted(input.text)
            }
        }
    }
}
