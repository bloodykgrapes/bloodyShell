import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

QtObject
{
    component Tint: Behavior
    {
        id: tint
        property int duration: 140
        enabled: Theme.animationsEnabled
        ColorAnimation { duration: tint.duration; easing.type: Easing.OutCubic }
    }

    component Spring: Behavior
    {
        enabled: Theme.animationsEnabled
        NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }

    component Morph: Behavior
    {
        enabled: Theme.animationsEnabled
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    component Shadow: RectangularShadow
    {
        property Item target: parent
        anchors.fill: target
        z: target === parent ? -1 : 0
        radius: target ? target.radius : 0
        scale: target && target !== parent ? target.scale : 1
        blur: 18
        spread: 1
        offset.y: 3
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    component TextShadow: MultiEffect
    {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.7
        shadowBlur: 0.5
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 0
    }

    component Label: Text
    {
        property int size: 12
        color: Theme.text2
        font.pixelSize: size
        font.family: Theme.fontText
        elide: Text.ElideRight
    }

    component Button: Rectangle
    {
        id: button

        property string icon: ""
        property string label: ""
        property int size: 40
        property int iconSize: Math.round(size * 0.42)
        signal clicked()

        width: size
        height: size
        activeFocusOnTab: true
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        border.width: 1
        border.color: activeFocus ? Theme.text1 : Theme.colorLine
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: clicked()
        radius: area.containsMouse ? Math.round(size * 0.3) : size / 2
        Morph on radius {}
        color: area.pressed ? Theme.colorPressed : area.containsMouse ? Theme.colorHover : Theme.surface
        Tint on color {}
        scale: area.pressed ? 0.9 : area.containsMouse ? 1.04 : 1
        Spring on scale {}
        Shadow {}

        Image
        {
            anchors.centerIn: parent
            source: button.icon
            width: button.iconSize
            height: width
            sourceSize: Qt.size(width * 2, width * 2)
            opacity: button.enabled ? 1 : 0.3
        }

        MouseArea
        {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component PasswordField: Item
    {
        id: f

        property bool reveal: false
        property bool plain: false
        readonly property alias text: input.text

        property bool busy: false
        property bool failed: false
        property bool closed: false
        signal submitted(string password)
        signal edited()
        signal cancelled()

        function clear() { input.text = ""; reveal = false }
        function focusInput() { input.forceActiveFocus() }

        height: 44

        readonly property int padding: 18
        readonly property real dot: 12
        readonly property real dotStep: dot + 7
        readonly property real counterRoom: 30
        readonly property real dotsRoom: width - padding - buttons.width - 14 - counterRoom
        readonly property int dotsMax: Math.max(4, Math.floor((dotsRoom + 7) / dotStep))
        readonly property int length: input.text.length
        readonly property int dotsShown: Math.min(length, dotsMax)

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
            color: input.activeFocus || f.reveal ? Theme.colorFieldFocus : Theme.colorField
            border.width: 1
            border.color: f.failed ? Theme.colorCritical : input.activeFocus ? Theme.colorAccent : Theme.colorLine
            Tint on color {}
            Tint on border.color {}
            Shadow {}
        }

        TextInput
        {
            id: input
            anchors.fill: parent
            leftPadding: f.padding
            rightPadding: buttons.width + 16
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            focus: true
            opacity: f.reveal || f.plain ? 1 : 0
            echoMode: f.reveal || f.plain ? TextInput.Normal : TextInput.Password
            font.family: Theme.fontText
            font.pixelSize: 15
            color: Theme.text1
            selectionColor: Theme.colorSelection
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            readOnly: f.busy || f.closed

            Component.onCompleted: forceActiveFocus()
            onAccepted: f.submitted(text)
            onTextEdited: f.edited()

            Keys.onPressed: event =>
            {
                if (event.key === Qt.Key_Escape || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Backspace))
                {
                    input.text = "";
                    if (event.key === Qt.Key_Escape) f.cancelled();
                    event.accepted = true;
                }
            }
        }

        Item
        {
            x: f.padding
            width: f.dotsRoom + f.counterRoom
            height: parent.height
            visible: !f.reveal && !f.plain

            Repeater
            {
                model: f.dotsMax
                Item
                {
                    id: dotItem
                    required property int index
                    readonly property bool on: index < f.dotsShown
                    readonly property int shape: f.shapes[index] !== undefined ? f.shapes[index] : 0
                    readonly property real size: f.dot + 4
                    x: index * f.dotStep - 2
                    y: (parent.height - height) / 2
                    width: size
                    height: size
                    scale: 0
                    rotation: -120
                    opacity: 0
                    visible: scale > 0.01
                    function show(now)
                    {
                        appear.stop(); leave.stop();
                        if (now || !Theme.animationsEnabled) { scale = on ? 1 : 0; rotation = on ? 0 : -120; opacity = on ? 1 : 0; return; }
                        (on ? appear : leave).start();
                    }
                    onOnChanged: show(false)
                    Component.onCompleted: show(true)
                    ParallelAnimation
                    {
                        id: appear
                        NumberAnimation { target: dotItem; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                        NumberAnimation { target: dotItem; property: "rotation"; to: 0; duration: 340; easing.type: Easing.OutCubic }
                        NumberAnimation { target: dotItem; property: "opacity"; to: 1; duration: 90 }
                    }
                    ParallelAnimation
                    {
                        id: leave
                        NumberAnimation { target: dotItem; property: "scale"; to: 0; duration: 150; easing.type: Easing.InBack }
                        NumberAnimation { target: dotItem; property: "rotation"; to: -120; duration: 150; easing.type: Easing.InCubic }
                        NumberAnimation { target: dotItem; property: "opacity"; to: 0; duration: 150 }
                    }

                    Rectangle
                    {
                        visible: dotItem.shape < 2
                        anchors.centerIn: parent
                        width: dotItem.shape === 0 ? f.dot : f.dot * 0.94
                        height: width
                        radius: dotItem.shape === 0 ? width / 2 : width * 0.28
                        color: Theme.text1
                        antialiasing: true
                    }

                    Shape
                    {
                        visible: dotItem.shape === 2
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath
                        {
                            fillColor: Theme.text1
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
                x: f.dotsShown * f.dotStep
                y: (parent.height - height) / 2
                width: 2
                height: f.dot + 10
                radius: 1
                color: Theme.colorAccent
                visible: input.activeFocus && !f.busy && f.length <= f.dotsShown
                Behavior on x { enabled: Theme.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                SequentialAnimation on opacity
                {
                    running: caret.visible && Theme.animationsEnabled
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 500; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1;    duration: 500; easing.type: Easing.InOutQuad }
                }
            }
            Label
            {
                x: f.dotsShown * f.dotStep + 2
                anchors.verticalCenter: parent.verticalCenter
                visible: f.length > f.dotsShown
                text: "+" + (f.length - f.dotsShown)
                font.weight: Font.DemiBold
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
                Morph on radius {}
                color: eyeArea.pressed ? Theme.colorPressed : eyeArea.containsMouse ? Theme.colorHover : Theme.colorField
                Tint on color {}
                scale: eyeArea.pressed ? 0.9 : eyeArea.containsMouse ? 1.08 : 1
                Spring on scale {}
                Image
                {
                    anchors.centerIn: parent
                    source: Theme.icon(f.reveal ? "visibility_off" : "visibility")
                    width: 14; height: 14; sourceSize: Qt.size(28, 28)
                    opacity: f.reveal || eyeArea.containsMouse ? 1 : 0.6
                }
                MouseArea
                {
                    id: eyeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { f.reveal = !f.reveal; input.forceActiveFocus() }
                }
            }

            Rectangle
            {
                id: submit
                readonly property bool ready: !f.busy && input.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 34; radius: submitArea.containsMouse ? 10 : 17
                Morph on radius {}
                color: f.busy ? Theme.colorLine : ready ? Theme.colorAccent : submitArea.containsMouse ? Theme.colorHover : Theme.surfaceStrong
                scale: submitArea.pressed ? 0.9 : submitArea.containsMouse ? 1.08 : 1
                Tint on color { duration: 160 }
                Spring on scale {}

                Image
                {
                    anchors.centerIn: parent
                    width: 14; height: 14
                    sourceSize: Qt.size(28, 28)
                    source: Theme.icon(f.busy ? "reload" : submit.ready ? "chevron_right_dark" : "chevron_right")
                    RotationAnimation on rotation { running: f.busy && Theme.animationsEnabled; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                    onSourceChanged: rotation = 0
                }
                MouseArea
                {
                    id: submitArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !f.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: f.submitted(input.text)
                }
            }
        }
    }
}
