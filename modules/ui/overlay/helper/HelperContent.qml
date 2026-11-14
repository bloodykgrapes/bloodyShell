pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls

import "." as Content
import "../../../animations"
import "../../../common"
import "../../../core"
import "../settings/components"

Rectangle
{
    id: helperContent

    signal finished()

    property int currentPage: 0
    property int direction: 1
    property real pageReveal: 1
    readonly property int inset: 24
    readonly property var steps: [
        {label: Tr.tr("helper.start"), title: Tr.tr("helper.welcome"), hint: Tr.tr("helper.welcomeHint")},
        {label: Tr.tr("common.display"), title: Tr.tr("common.display"), hint: Tr.tr("helper.displayHint")},
        {label: Tr.tr("common.appearance"), title: Tr.tr("common.appearance"), hint: Tr.tr("helper.appearanceHint")},
        {label: Tr.tr("helper.layout"), title: Tr.tr("helper.layout"), hint: Tr.tr("helper.layoutHint")},
        {label: Tr.tr("helper.input"), title: Tr.tr("helper.input"), hint: Tr.tr("helper.inputHint")},
        {label: Tr.tr("helper.ready"), title: Tr.tr("helper.ready"), hint: Tr.tr("helper.readyHint")}
    ]
    readonly property bool saving: pages.saving
    readonly property string saveError: pages.saveError

    implicitWidth: 800
    implicitHeight: 640
    radius: Theme.settingsRadius
    color: Theme.colorSolid
    focus: true
    Component.onCompleted: forceActiveFocus()

    function go(index)
    {
        const next = Math.max(0, Math.min(steps.length - 1, index));
        if (next === currentPage) return;
        direction = next > currentPage ? 1 : -1;
        scrolling.stop();
        content.cancelFlick();
        currentPage = next;
        content.contentY = 0;
        arrival.stop();
        pageReveal = Config.animationsEnabled ? 0 : 1;
        if (Config.animationsEnabled) arrival.start();
        forceActiveFocus(Qt.TabFocusReason);
    }

    function advance()
    {
        if (currentPage === steps.length - 1) { if (!saving) finished(); }
        else go(currentPage + 1);
    }

    NumberAnimation
    {
        id: arrival
        target: helperContent
        property: "pageReveal"
        to: 1
        duration: Theme.animationDurationControl
        easing.type: Easing.OutCubic
    }

    Connections
    {
        target: Config
        function onAnimationsEnabledChanged()
        {
            if (Config.animationsEnabled) return;
            arrival.stop();
            helperContent.pageReveal = 1;
        }
    }

    Keys.onPressed: event =>
    {
        if (![Qt.Key_Return, Qt.Key_Enter, Qt.Key_Escape, Qt.Key_Left, Qt.Key_Right, Qt.Key_Home, Qt.Key_End].includes(event.key)) return;
        event.accepted = true;
        if (event.isAutoRepeat) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) advance();
        else if (event.key === Qt.Key_Escape) finished();
        else if (event.key === Qt.Key_Left) go(currentPage - 1);
        else if (event.key === Qt.Key_Right) go(currentPage + 1);
        else go(event.key === Qt.Key_Home ? 0 : steps.length - 1);
    }

    MouseArea { anchors.fill: parent; onClicked: helperContent.forceActiveFocus() }

    Item
    {
        id: brand
        x: helperContent.inset
        y: 20
        width: parent.width - helperContent.inset * 2
        height: 36
        Row
        {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            ShellIcon { anchors.verticalCenter: parent.verticalCenter; icon: Icon.settingsGeneral; size: 20 }
            ShellText { anchors.verticalCenter: parent.verticalCenter; label: "bloodyShell"; size: 14; font.weight: Font.DemiBold; color: Theme.text1 }
            ShellText { anchors.verticalCenter: parent.verticalCenter; visible: helperContent.width > 500; label: Tr.tr("helper.setup"); size: 11; color: Theme.text3 }
        }
        SettingsIconButton
        {
            objectName: "helperClose"
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            icon: Icon.close
            text: Tr.tr("common.close")
            onClicked: helperContent.finished()
        }
    }

    Row
    {
        id: stepNavigation
        x: helperContent.inset
        y: brand.y + brand.height + 16
        width: parent.width - helperContent.inset * 2
        spacing: 6
        Repeater
        {
            model: helperContent.steps
            Rectangle
            {
                id: step
                required property int index
                required property var modelData
                readonly property bool current: index === helperContent.currentPage
                width: (stepNavigation.width - stepNavigation.spacing * (helperContent.steps.length - 1)) / helperContent.steps.length
                height: 36
                radius: Theme.radiusMedium
                color: current ? Theme.colorSelection : Theme.colorField
                objectName: "helperStep-" + index
                activeFocusOnTab: true
                Tint on color {}
                Keys.onSpacePressed: event => { if (!event.isAutoRepeat) helperContent.go(index); event.accepted = true }
                Keys.onReturnPressed: event => { if (!event.isAutoRepeat) helperContent.go(index); event.accepted = true }
                Keys.onEnterPressed: event => { if (!event.isAutoRepeat) helperContent.go(index); event.accepted = true }
                Accessible.role: Accessible.Button
                Accessible.name: modelData.title
                Accessible.onPressAction: helperContent.go(index)
                Rectangle
                {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.colorHover
                    opacity: stepHover.hovered || step.activeFocus ? 1 : 0
                    Smooth on opacity {}
                }
                Row
                {
                    anchors.centerIn: parent
                    spacing: 7
                    ShellText { label: String(step.index + 1); size: 11; font.family: Theme.fontMono; color: step.current ? Theme.text1 : Theme.text3 }
                    ShellText { visible: helperContent.width >= 560; width: Math.max(0, step.width - 38); label: step.modelData.label; size: 11; font.weight: step.current ? Font.DemiBold : Font.Normal; color: step.current ? Theme.text1 : Theme.text2 }
                }
                HoverHandler { id: stepHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: helperContent.go(step.index) }
            }
        }
    }

    Column
    {
        id: heading
        x: helperContent.inset
        y: stepNavigation.y + stepNavigation.height + 20
        width: parent.width - helperContent.inset * 2
        spacing: 8

        ShellText { width: parent.width; label: helperContent.steps[helperContent.currentPage].title; size: 24; font.weight: Font.DemiBold; color: Theme.text1; wrapMode: Text.Wrap }
        ShellText { width: parent.width; label: helperContent.steps[helperContent.currentPage].hint; size: 12; wrapMode: Text.Wrap; color: Theme.text2 }
    }

    Flickable
    {
        id: content
        objectName: "helperContentScroll"
        x: helperContent.inset
        y: heading.y + heading.height + 18
        width: parent.width - helperContent.inset * 2
        height: Math.max(0, navigation.y - y - 20)
        contentWidth: width
        contentHeight: pages.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        opacity: helperContent.pageReveal
        transform: Translate { x: Config.animationsFluid ? (1 - helperContent.pageReveal) * 20 * helperContent.direction : 0 }

        SmoothScroll { id: scrolling; view: content }
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

        Content.HelperPages
        {
            id: pages
            width: parent.width
            currentPage: helperContent.currentPage
            onNavigate: index => helperContent.go(index)
        }
    }

    Rectangle
    {
        anchors { left: parent.left; right: parent.right; bottom: navigation.top; bottomMargin: 16; leftMargin: helperContent.inset; rightMargin: helperContent.inset }
        height: 1
        color: Theme.settingsColorLine
    }

    Item
    {
        id: navigation
        x: helperContent.inset
        y: parent.height - height - 24
        width: parent.width - helperContent.inset * 2
        height: Theme.settingsControlHeight

        SettingsButton
        {
            id: back
            objectName: "helperBack"
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: Tr.tr("helper.back")
            icon: Icon.chevronLeft
            enabled: helperContent.currentPage > 0
            onClicked: helperContent.go(helperContent.currentPage - 1)
        }

        ShellText
        {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - back.width - next.width - 32)
            horizontalAlignment: Text.AlignHCenter
            label: (helperContent.currentPage + 1) + " / " + helperContent.steps.length
            color: Theme.text3
            size: 11
            font.family: Theme.fontMono
        }

        SettingsButton
        {
            id: next
            objectName: "helperNext"
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: helperContent.currentPage === helperContent.steps.length - 1 ? Tr.tr("helper.finish") : Tr.tr("helper.next")
            icon: helperContent.currentPage === helperContent.steps.length - 1 ? Icon.check : Icon.chevronRight
            enabled: helperContent.currentPage !== helperContent.steps.length - 1 || !helperContent.saving
            onClicked: helperContent.advance()
        }
    }
}
