pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

import "../../../animations"
import "../../../common"
import "../../../core"
import "../../../services"
import "../components"

Menu
{
    id: menuTray
    centerOnWidget: true

    readonly property int cell: Math.round(36 * Config.themeScale)
    readonly property int gap: Math.round(6 * Config.themeScale)
    readonly property int iconColumns: Math.max(1, Math.min(5, entries.length))
    readonly property real compactWidth: entries.length > 0
        ? iconColumns * cell + (iconColumns - 1) * gap + Theme.menuPadding * 2 + 12
        : Math.max(180 * Config.themeScale, emptyLabel.implicitWidth + Theme.menuPadding * 2)
    readonly property real maxListHeight: Math.round(288 * Config.themeScale)
    readonly property var entries: Array.from(SystemTray.items.values).filter(item => item.status !== Status.Passive)
    readonly property var requestedItem: MenuState.trayContextItem
    readonly property bool contextOpen: !!requestedItem && requestedItem.hasMenu
    property var contextItem: null
    readonly property bool hasContext: !!contextItem && contextItem.hasMenu
    readonly property var level:
    {
        const item = contextItem;
        if (!item || !item.hasMenu) return null;
        return stack.length > 0 ? stack[stack.length - 1] : item.menu;
    }
    readonly property string contextTitle: titleOf(contextItem)
    readonly property string levelTitle: !hasContext ? "" : stack.length > 0 && level ? level.text : contextTitle
    property var stack: []
    property bool mounted: false
    property int entryRevision: 0
    property int entryDirection: 1
    readonly property int contextDuration: Config.animationsFluid ? 320 : 180

    Component.onCompleted: { mounted = true; syncContext() }

    implicitWidth: contextOpen || contextSection.reveal > 0.001 ? Math.max(Theme.menuWidth, compactWidth) : compactWidth

    function titleOf(item) { return item ? (item.tooltipTitle || item.title || item.id || "") : "" }

    function toggleContext(item)
    {
        MenuState.trayContextItem = requestedItem === item ? null : item;
    }

    function releaseContext()
    {
        releaseTimer.stop();
        contextItem = null;
        stack = [];
    }

    function syncContext()
    {
        if (!mounted) return;
        const next = requestedItem;
        if (next && next.hasMenu)
        {
            releaseTimer.stop();
            stack = [];
            contextItem = next;
            ctx.slide(1);
        }
        else if (Config.animationsEnabled) releaseTimer.restart();
        else releaseContext();
    }

    function activate(entry)
    {
        if (!entry || !entry.enabled || entry.isSeparator) return;
        if (entry.hasChildren)
        {
            stack = stack.concat([entry]);
            ctx.slide(1);
            return;
        }
        entry.triggered();
        MenuState.close();
    }

    function back()
    {
        if (stack.length === 0) return;
        stack = stack.slice(0, -1);
        ctx.slide(-1);
    }

    onRequestedItemChanged: syncContext()
    onContextOpenChanged: syncContext()
    onLevelChanged: if (actions) actions.contentY = 0
    onEntriesChanged:
    {
        if (requestedItem && !entries.includes(requestedItem)) MenuState.trayContextItem = null;
    }
    Keys.onEscapePressed: event =>
    {
        if (contextOpen && stack.length > 0) back();
        else if (contextOpen) MenuState.trayContextItem = null;
        else MenuState.close();
        event.accepted = true;
    }
    Keys.onLeftPressed: event =>
    {
        if (contextOpen && stack.length > 0) back();
        else event.accepted = false;
    }

    QsMenuOpener { id: opener; menu: menuTray.level }
    Timer
    {
        id: releaseTimer
        interval: menuTray.contextDuration + 40
        onTriggered: if (!menuTray.contextOpen) menuTray.releaseContext()
    }

    RevealSection
    {
        shown: menuTray.presented
        order: 0

        Flickable
        {
            objectName: "trayApps"
            width: parent.width
            height: Math.min(contentHeight, menuTray.cell * 3 + menuTray.gap * 2 + 12)
            contentHeight: grid.implicitHeight + 12
            contentWidth: width
            visible: menuTray.entries.length > 0
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Grid
            {
                id: grid
                x: Math.round((parent.width - width) / 2)
                y: 6
                columns: menuTray.iconColumns
                spacing: menuTray.gap

                Repeater
                {
                    model: menuTray.entries
                    TrayButton
                    {
                        required property var modelData
                        objectName: "trayApp"
                        width: menuTray.cell
                        height: menuTray.cell
                        radius: 12
                        iconSize: Math.round(18 * Config.themeScale)
                        trayItem: modelData
                        active: menuTray.requestedItem === modelData
                        backgroundColor: Qt.tint(Theme.frameColor, pressed ? Theme.colorPressed : active ? Theme.colorChosen
                            : containsMouse || activeFocus ? Theme.colorHoverStrong : Theme.colorField)
                        onLaunched: MenuState.close()
                        onContextRequested: menuTray.toggleContext(modelData)
                    }
                }
            }
        }
        Column
        {
            width: parent.width
            height: 88
            visible: menuTray.entries.length === 0
            topPadding: 16
            spacing: 10
            ShellIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: Icon.tray; size: 28; opacity: 0.4 }
            ShellText { id: emptyLabel; width: parent.width; horizontalAlignment: Text.AlignHCenter; label: Tr.tr("menu.tray.noAppsInTray"); size: 12; color: Theme.text3 }
        }
    }
    Item
    {
        id: contextSection
        width: parent.width
        height: ctx.height * reveal
        visible: reveal > 0
        enabled: menuTray.contextOpen
        clip: reveal < 1

        property real progress: menuTray.contextOpen ? 1 : 0
        readonly property real reveal: Config.animationsEnabled ? progress : menuTray.contextOpen ? 1 : 0
        Glide on progress { id: contextMotion; duration: menuTray.contextDuration }

        Rectangle
        {
            id: ctx
            objectName: "trayContext"
            width: parent.width
            height: contextBody.implicitHeight + 16
            radius: Theme.radiusLarge
            color: Theme.colorField
            opacity: contextSection.reveal
            scale: Config.animationsFluid ? 0.97 + 0.03 * contextSection.reveal : 1
            transform: Translate { y: Config.animationsEnabled ? 8 * (1 - contextSection.reveal) : 0 }

            property real shift: 0
            function slide(direction)
            {
                menuTray.entryDirection = direction;
                menuTray.entryRevision++;
                slideIn.stop();
                shift = Config.animationsEnabled ? direction * (Config.animationsFluid ? 24 : 12) : 0;
                content.opacity = Config.animationsEnabled ? 0 : 1;
                if (Config.animationsEnabled) slideIn.start();
            }
            ParallelAnimation
            {
                id: slideIn
                NumberAnimation { target: ctx; property: "shift"; to: 0; duration: Theme.animationDurationMorph; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized }
                NumberAnimation { target: content; property: "opacity"; to: 1; duration: Config.animationsFluid ? 220 : 140; easing.type: Easing.OutCubic }
            }
            Connections
            {
                target: Config
                function onAnimationsEnabledChanged()
                {
                    if (Config.animationsEnabled) return;
                    contextMotion.animation.complete();
                    ctx.slide(0);
                    if (!menuTray.contextOpen) menuTray.releaseContext();
                }
            }

            Column
            {
                id: contextBody
                x: 8; y: 8
                width: parent.width - 16
                spacing: 4

                Item
                {
                    width: parent.width
                    height: 36
                    ActionButton
                    {
                        id: backButton
                        objectName: "trayBack"
                        x: 2
                        anchors.verticalCenter: parent.verticalCenter
                        iconOnly: true
                        icon: Icon.chevronLeft
                        iconSize: 14
                        visible: menuTray.stack.length > 0
                        Accessible.name: Tr.tr("common.back")
                        onClicked: menuTray.back()
                    }
                    Image
                    {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22
                        visible: menuTray.stack.length === 0
                        source: menuTray.contextItem ? ServiceApplications.trayIcon(menuTray.contextItem.icon) : ""
                        sourceSize: Qt.size(44, 44)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    ShellText
                    {
                        anchors { left: parent.left; leftMargin: 40; right: closeButton.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        label: menuTray.levelTitle
                        textFormat: Text.PlainText
                        size: 12
                        font.weight: Font.DemiBold
                        color: Theme.text1
                    }
                    ActionButton
                    {
                        id: closeButton
                        objectName: "trayCloseContext"
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        iconOnly: true
                        icon: Icon.close
                        iconSize: 12
                        Accessible.name: Tr.tr("common.close")
                        onClicked: MenuState.trayContextItem = null
                    }
                }
                MenuSeparator {}
                Item
                {
                    x: -8
                    width: parent.width + 16
                    height: content.implicitHeight + 8
                    clip: true

                    Column
                    {
                        id: content
                        x: 8; y: 4
                        width: parent.width - 16
                        transform: Translate { x: ctx.shift }

                        MenuList
                        {
                            id: actions
                            objectName: "trayActions"
                            model: opener.children
                            maxHeight: menuTray.maxListHeight
                            add: null
                            remove: null
                            displaced: null
                            onCountChanged: contentY = 0
                            delegate: TrayMenuEntry
                            {
                                required property var modelData
                                required property int index
                                entry: modelData
                                order: index
                                direction: menuTray.entryDirection
                                revision: menuTray.entryRevision
                                presented: menuTray.contextOpen
                                onTriggered: menuTray.activate(modelData)
                            }
                        }
                        MenuLabel
                        {
                            hint: true
                            visible: opener.children.values.length === 0
                            text: Tr.tr("menu.tray.noActions")
                        }
                    }
                }
            }
        }
    }
}
