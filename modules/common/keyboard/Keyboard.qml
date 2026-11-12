pragma ComponentBehavior: Bound

import QtQuick

import "." as Parts

Rectangle
{
    id: keyboard
    objectName: "virtualKeyboard"

    property var engine: null
    property var layouts: [{layout: "us", variant: ""}]
    property int layoutIndex: 0
    property bool animations: true
    property bool fluid: false
    property string family: "sans-serif"
    property var colors: ({surface: "#161618", key: "#242428", hover: "#2c2c32", pressed: "#3a3a42", text: "#f5f5f7", muted: "#a1a1aa", accent: "#f5f5f7", onAccent: "#161618"})
    property var labels: ({title: "On-screen keyboard", loading: "Preparing keyboard…", unavailable: "Could not load the on-screen keyboard.", close: "Hide keyboard", space: "Space", nextLayout: "Next layout", shift: "Shift", caps: "Caps Lock", backspace: "Backspace", enter: "Enter", symbols: "Symbols", letters: "Letters", alternate: "Alternate characters"})
    property string status: engine ? engine.error : ""
    readonly property bool available: engine !== null && engine.ready
    readonly property bool hasLayout: engine !== null && engine.rows.length === 4 && engine.rows.every(row => row.length > 0)
    property bool shifted: false
    property bool caps: false
    property bool alternate: false
    property bool symbols: false
    readonly property real gap: 5
    readonly property real keyHeight: Math.max(30, Math.min(46, width * 0.057))
    readonly property var selectedLayout: layouts[Math.min(layoutIndex, layouts.length - 1)] || {layout: "us", variant: ""}

    signal dismissed()
    signal layoutSelected(int index)

    implicitWidth: 840
    implicitHeight: 32 + keyHeight * 5 + gap * 5 + 28
    radius: 24
    color: colors.surface

    function syncLayout()
    {
        if (!engine) return;
        engine.layout = selectedLayout.layout;
        engine.variant = selectedLayout.variant || "";
        engine.symbols = symbols;
    }
    onEngineChanged: syncLayout()
    onSelectedLayoutChanged: syncLayout()
    onSymbolsChanged: { shifted = false; alternate = false; syncLayout(); }
    function reset() { shifted = false; caps = false; alternate = false; symbols = false; if (engine) engine.reset(); }
    onVisibleChanged: if (!visible) reset()

    function character(code, shift)
    {
        return {code: code, shift: shift, weight: 1};
    }
    function action(name, text, code, weight = 1.45)
    {
        return {action: name, text: text, code: code, weight: weight};
    }
    readonly property var rows:
    {
        if (!hasLayout) return [];
        if (symbols) return [
            [2,3,4,5,6,7,8,9,10,11].map(c => character(c, false)).concat([action("backspace", "⌫", 14, 1.7)]),
            [2,3,4,5,6,7,8,9,10,11].map(c => character(c, true)).concat([character(12, false), character(13, false)]),
            [26,27,43,39,40,41,51,52,53].map(c => character(c, false)).concat([action("enter", "↵", 28, 1.7)]),
            [26,27,43,39,40,41,51,52,53,12,13].map(c => character(c, true))
        ];
        const data = engine.rows;
        return [
            data[0].concat([action("backspace", "⌫", 14, 1.7)]),
            [action("tab", "⇥", 15)].concat(data[1]),
            [action("caps", "⇪", 0)].concat(data[2], [action("enter", "↵", 28)]),
            [action("shift", "⇧", 0, 1.8)].concat(data[3], [action("shift", "⇧", 0, 1.8)])
        ];
    }

    function caption(key)
    {
        if (key.action) return key.text;
        if (!engine) return "";
        return engine.label(key.code, symbols ? !!key.shift : shifted, symbols ? false : caps, alternate);
    }
    function activate(key)
    {
        if (key.action === "shift") { shifted = !shifted; return; }
        if (key.action === "caps") { caps = !caps; return; }
        if (!available) return;
        if (engine.tap(key.code, symbols ? !!key.shift : shifted, symbols ? false : caps, alternate) && !key.action)
            shifted = false;
    }

    Column
    {
        id: keys
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: keyboard.gap

        Item
        {
            width: parent.width
            height: 32
            Text
            {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; right: language.left; rightMargin: 12 }
                text: keyboard.hasLayout ? keyboard.status || keyboard.labels.title : keyboard.labels.title
                font { family: keyboard.family; pixelSize: 12; weight: Font.Medium }
                color: keyboard.colors.muted
                elide: Text.ElideRight
            }
            Parts.Key
            {
                host: keyboard
                id: language
                objectName: "virtualKeyboardLayout"
                anchors { right: close.left; rightMargin: 5 }
                width: 70; height: 28
                text: keyboard.selectedLayout.layout.toUpperCase()
                description: keyboard.labels.nextLayout
                visible: keyboard.layouts.length > 1 && keyboard.hasLayout
                textSize: 11
                onActivated:
                {
                    keyboard.layoutSelected((keyboard.layoutIndex + 1) % keyboard.layouts.length);
                }
            }
            Parts.Key
            {
                host: keyboard
                id: close
                enabled: true
                objectName: "virtualKeyboardClose"
                anchors.right: parent.right
                width: 32; height: 28
                text: "⌄"; description: keyboard.labels.close
                onActivated: keyboard.dismissed()
            }
        }

        Repeater
        {
            model: keyboard.rows
            Row
            {
                id: keyRow
                required property var modelData
                required property int index
                readonly property real units: modelData.reduce((sum, key) => sum + (key.weight || 1), 0)
                readonly property real unitWidth: (width - keyboard.gap * (modelData.length - 1)) / Math.max(1, units)
                width: keys.width
                height: keyboard.keyHeight
                spacing: keyboard.gap
                Repeater
                {
                    model: keyRow.modelData
                    Parts.Key
                    {
                        host: keyboard
                        id: key
                        required property var modelData
                        objectName: "virtualKey" + modelData.code + (modelData.shift ? "Shift" : "")
                        width: keyRow.unitWidth * (modelData.weight || 1)
                        text: keyboard.caption(modelData)
                        description: modelData.action ? (keyboard.labels[modelData.action] || text) : text
                        checked: modelData.action === "shift" ? keyboard.shifted : modelData.action === "caps" && keyboard.caps
                        accent: modelData.action === "enter"
                        repeatable: modelData.action === "backspace"
                        onActivated: keyboard.activate(modelData)
                    }
                }
            }
        }

        Item
        {
            objectName: "virtualKeyboardStatus"
            visible: !keyboard.hasLayout
            width: parent.width
            height: keyboard.keyHeight * 5 + keyboard.gap * 4

            Text
            {
                anchors { fill: parent; margins: 24 }
                text: keyboard.status || keyboard.labels.loading
                font { family: keyboard.family; pixelSize: 13 }
                color: keyboard.colors.muted
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Row
        {
            visible: keyboard.hasLayout
            width: parent.width
            height: keyboard.keyHeight
            spacing: keyboard.gap
            Parts.Key
            {
                host: keyboard
                objectName: "virtualKeyboardSymbols"
                width: parent.width * 0.11
                text: keyboard.symbols ? "ABC" : "123"
                description: keyboard.symbols ? keyboard.labels.letters : keyboard.labels.symbols
                checked: keyboard.symbols
                textSize: 13
                onActivated: keyboard.symbols = !keyboard.symbols
            }
            Parts.Key
            {
                host: keyboard
                width: parent.width * 0.11
                text: "AltGr"; description: keyboard.labels.alternate
                checked: keyboard.alternate
                textSize: 12
                enabled: keyboard.available && !keyboard.symbols
                onActivated: keyboard.alternate = !keyboard.alternate
            }
            Parts.Key
            {
                host: keyboard
                objectName: "virtualKeyboardSpace"
                width: parent.width - parent.width * 0.44 - keyboard.gap * 4
                text: keyboard.labels.space
                textSize: 12
                onActivated: keyboard.activate({code: 57})
            }
            Repeater
            {
                model: [{code: 105, text: "←"}, {code: 106, text: "→"}]
                Parts.Key
                {
                    host: keyboard
                    required property var modelData
                    width: keys.width * 0.11
                    text: modelData.text
                    repeatable: true
                    onActivated: keyboard.activate(modelData)
                }
            }
        }
    }
}
