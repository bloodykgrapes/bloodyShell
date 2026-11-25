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
    implicitHeight: 28 + keyHeight * 5 + gap * 5 + 28
    Accessible.role: Accessible.Pane
    Accessible.name: labels.title
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
    readonly property var letterRows: hasLayout ? engine.rows.slice(1).map(row => row.filter(key => engine.isLetter(key.code))) : []
    readonly property int letterColumns: letterRows.length === 3 ? Math.max(letterRows[0].length, letterRows[1].length, letterRows[2].length + 2) : 10
    readonly property real letterWidth: Math.max(0, (keys.width - gap * (letterColumns - 1)) / Math.max(1, letterColumns))

    function digit(code)
    {
        const shiftedDigit = !/^[0-9]$/.test(engine.label(code, false, false)) && /^[0-9]$/.test(engine.label(code, true, false));
        return {code: code, fixedShift: shiftedDigit};
    }
    readonly property var rows:
    {
        if (!hasLayout || letterRows.length !== 3) return [];
        if (symbols) return [
            [2,3,4,5,6,7,8,9,10,11].map(c => character(c, false)).concat([action("backspace", "Backspace", 14, 1.5)]),
            [2,3,4,5,6,7,8,9,10,11].map(c => character(c, true)).concat([character(12, false), character(13, false)]),
            [26,27,43,39,40,41,51,52,53].map(c => character(c, false)),
            [26,27,43,39,40,41,51,52,53,12,13].map(c => character(c, true))
        ];
        return [
            [2,3,4,5,6,7,8,9,10,11].map(digit),
            letterRows[0],
            letterRows[1],
            [action("shift", "Shift", 0, 1.5)].concat(letterRows[2], [action("backspace", "Backspace", 14, 1.5)])
        ];
    }

    function caption(key)
    {
        if (key.action) return key.text;
        if (!engine) return "";
        return engine.label(key.code, key.fixedShift !== undefined ? key.fixedShift : symbols ? !!key.shift : shifted, key.fixedShift !== undefined || symbols ? false : caps, alternate);
    }
    function activate(key)
    {
        if (key.action === "shift") { if (caps) { caps = false; shifted = false; } else shifted = !shifted; return; }
        if (!available) return;
        if (engine.tap(key.code, key.fixedShift !== undefined ? key.fixedShift : symbols ? !!key.shift : shifted, key.fixedShift !== undefined || symbols ? false : caps, alternate) && !key.action)
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
            height: 28
            Text
            {
                anchors { left: language.right; leftMargin: 12; verticalCenter: parent.verticalCenter; right: close.left; rightMargin: 12 }
                visible: keyboard.hasLayout && keyboard.status !== ""
                text: keyboard.status
                font { family: keyboard.family; pixelSize: 12; weight: Font.Medium }
                color: keyboard.colors.muted
                elide: Text.ElideRight
            }
            Parts.Key
            {
                host: keyboard
                id: language
                objectName: "virtualKeyboardLayout"
                anchors.left: parent.left
                width: 70; height: 28
                text: keyboard.selectedLayout.layout.toUpperCase()
                description: keyboard.labels.nextLayout
                visible: keyboard.hasLayout
                textSize: 11
                onActivated:
                {
                    keyboard.layoutSelected((keyboard.layoutIndex + 1) % keyboard.layouts.length);
                }
            }
            Row
            {
                id: navigation
                anchors { left: language.right; leftMargin: 6 }
                spacing: 5
                visible: keyboard.hasLayout && keyboard.status === ""
                Repeater
                {
                    model: [{code:105, icon:"left", label:"Left"}, {code:106, icon:"right", label:"Right"}, {code:15, icon:"tab", label:"Tab"}]
                    Parts.Key
                    {
                        required property var modelData
                        host: keyboard
                        objectName: "virtualKey" + modelData.code
                        width: 32; height: 28
                        iconName: modelData.icon
                        description: modelData.label
                        repeatable: modelData.code !== 15
                        onActivated: keyboard.activate(modelData)
                    }
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
                iconName: "close"; description: keyboard.labels.close
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
                readonly property int characters: modelData.filter(key => !key.action).length
                readonly property real actionUnits: modelData.reduce((sum, key) => sum + (key.action ? key.weight || 1 : 0), 0)
                readonly property bool letterRow: !keyboard.symbols && (index === 1 || index === 2)
                readonly property real characterWidth: !keyboard.symbols && index > 0 ? keyboard.letterWidth
                    : Math.max(0, (width - keyboard.gap * (modelData.length - 1)) / Math.max(1, characters + actionUnits))
                readonly property real actionWidth: actionUnits > 0
                    ? (width - keyboard.gap * (modelData.length - 1) - characters * characterWidth) / actionUnits : 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: letterRow ? characters * keyboard.letterWidth + keyboard.gap * (characters - 1) : keys.width
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
                        width: modelData.action ? keyRow.actionWidth * (modelData.weight || 1) : keyRow.characterWidth
                        iconName: modelData.action === "shift" && keyboard.caps ? "caps" : modelData.action || ""
                        text: keyboard.caption(modelData)
                        description: modelData.action ? (keyboard.labels[modelData.action] || text) : text
                        checked: modelData.action === "shift" ? keyboard.shifted || keyboard.caps : false
                        accent: modelData.action === "enter"
                        repeatable: modelData.action === "backspace"
                        doubleActivatable: modelData.action === "shift"
                        onDoubleActivated: { keyboard.caps = true; keyboard.shifted = false; }
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
                width: parent.width * 0.10
                text: "AltGr"; description: keyboard.labels.alternate
                checked: keyboard.alternate
                textSize: 12
                enabled: keyboard.available && !keyboard.symbols
                onActivated: keyboard.alternate = !keyboard.alternate
            }
            Parts.Key
            {
                host: keyboard
                width: parent.width * 0.055
                text: ","
                onActivated: if (keyboard.engine) keyboard.engine.typeSymbol(",")
            }
            Parts.Key
            {
                host: keyboard
                objectName: "virtualKeyboardSpace"
                width: parent.width - parent.width * 0.47 - keyboard.gap * 5
                iconName: "space"
                text: keyboard.labels.space
                textSize: 12
                onActivated: keyboard.activate({code: 57})
            }
            Parts.Key
            {
                host: keyboard
                width: parent.width * 0.055
                text: "."
                onActivated: if (keyboard.engine) keyboard.engine.typeSymbol(".")
            }
            Parts.Key
            {
                host: keyboard
                objectName: "virtualKey28"
                width: parent.width * 0.15
                iconName: "enter"
                description: keyboard.labels.enter
                accent: true
                onActivated: keyboard.activate({code:28, action:"enter"})
            }
        }
    }
}
