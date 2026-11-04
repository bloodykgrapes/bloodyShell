pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Networking

import "../../components"
import "../../components/bar"
import "../../core"
import "../../services"
import "../../src/ModelSync.js" as ModelSync

Menu
{
    id: menuNetwork

    implicitWidth: 320

    property string passwordFor: ""
    property string status: ""

    Component.onCompleted:
    {
        ServiceNetwork.setScanning(true);
        ServiceNetwork.refreshAddress();
        syncNetworks();
    }
    Component.onDestruction:
    {
        ServiceNetwork.setScanning(false);
        MenuState.menuKeyboard = false;
    }

    function activate(name)
    {
        status = "";
        const typed = passwordFor === name && field.text !== "" ? field.text : undefined;
        const result = ServiceNetwork.connectNetwork(name, typed);

        if (result === "password")
        {
            passwordFor = name;
            field.text = "";
            MenuState.menuKeyboard = true;
            Qt.callLater(() => field.forceActiveFocus());
            return;
        }
        if (result === "settings") status = Tr.tr("menu.network.thisNetworkNeedsSettings");
        if (result === "unavailable") status = Tr.tr("menu.network.networkIsOutOfRange");

        cancelPassword();
    }

    function cancelPassword()
    {
        passwordFor = "";
        field.text = "";
        MenuState.menuKeyboard = false;
    }

    MenuToggle
    {
        icon: ServiceNetwork.enabledWiFi ? Icon.networkWiFiON : Icon.networkWiFiOFF
        text: Tr.tr("menu.network.wiFi")

        enabled: ServiceNetwork.hasWiFi && ServiceNetwork.enabledWiFiHardware
        checked: ServiceNetwork.enabledWiFi

        onToggle: value => ServiceNetwork.setWifiEnabled(value)
    }

    MenuRow
    {
        visible: ServiceNetwork.hasWired

        icon: Icon.networkEthernet
        text: Tr.tr("menu.network.ethernet")
        subtitle: ServiceNetwork.connectedEthernet ? Tr.tr("common.connected") : Tr.tr("menu.network.cableUnplugged")
        selected: ServiceNetwork.connectedEthernet
    }

    MenuSeparator { visible: ServiceNetwork.hasWiFi }

    MenuLabel
    {
        hint: true
        visible: ServiceNetwork.hasWiFi && !ServiceNetwork.enabledWiFi
        text: ServiceNetwork.enabledWiFiHardware ? Tr.tr("menu.network.wiFiIsOff") : Tr.tr("menu.network.wiFiIsBlockedByA")
    }

    Rectangle
    {
        id: card

        readonly property var active: ServiceNetwork.enabledWiFi ? ServiceNetwork.wifiList.find(n => n.connected) || null : null
        readonly property int strength: active ? ServiceNetwork.strengthPercent(active.strength) : 0

        visible: active !== null
        width: parent.width
        height: 58
        radius: Theme.radiusLarge
        color: Theme.colorCurrent

        scale: cardArea.pressed ? 0.98 : 1
        Spring on scale {}

        HoverHandler { id: cardHover }

        MouseArea
        {
            id: cardArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (card.active) menuNetwork.activate(card.active.name)
        }

        Rectangle
        {
            id: badge
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            width: 36
            height: 36
            radius: 18
            color: Theme.colorChosen

            ShellIcon { anchors.centerIn: parent; icon: Icon.wifiLevel(card.strength); size: 18 }
        }

        Column
        {
            anchors { left: badge.right; leftMargin: 10; right: cardActions.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 2

            ShellText
            {
                width: parent.width
                label: card.active ? card.active.name : ""
                size: 13
                color: Theme.text1
                font.weight: Font.Medium
            }
            ShellText
            {
                width: parent.width
                label: card.active && card.active.stateChanging ? Tr.tr("common.disconnecting")
                     : [Tr.tr("common.connected"), ServiceNetwork.wifiAddress, card.strength + "%"].filter(s => s !== "").join("  ·  ")
                size: 10
                color: Theme.text3
            }
        }

        Row
        {
            id: cardActions
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 2
            opacity: cardHover.hovered ? 1 : 0.55
            Smooth on opacity {}

            MenuRowAction { icon: Icon.linkOff; label: Tr.tr("common.disconnect"); onClicked: if (card.active) ServiceNetwork.disconnectNetwork(card.active.name) }
            MenuRowAction { icon: Icon.trash; label: Tr.tr("common.forget"); danger: true; onClicked: if (card.active) ServiceNetwork.forgetNetwork(card.active.name) }
        }
    }

    MenuLabel
    {
        visible: ServiceNetwork.enabledWiFi && networks.count > 0
        text: Tr.tr("menu.network.networks")
    }

    MenuLabel
    {
        hint: true
        visible: ServiceNetwork.enabledWiFi && ServiceNetwork.wifiList.length === 0
        text: Tr.tr("menu.network.searchingForNetworks")
    }

    ListModel { id: networks }

    function syncNetworks()
    {
        const seen = {};
        const list = (ServiceNetwork.enabledWiFi ? ServiceNetwork.wifiList : [])
            .filter(n => !n.connected && n.name !== ServiceNetwork.ssid && !seen[n.name] && (seen[n.name] = true));
        ModelSync.sync(networks, list.map(n => ({
            name: n.name,
            strength: ServiceNetwork.strengthPercent(n.strength),
            known: n.known === true,
            secured: n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe,
            changing: n.stateChanging === true
        })), "name");
    }

    Connections
    {
        target: ServiceNetwork
        function onWifiListChanged()  { menuNetwork.syncNetworks() }
        function onEnabledWiFiChanged() { menuNetwork.syncNetworks() }
    }

    MenuList
    {
        model: networks
        opening: menuNetwork.opening

        maxHeight: Math.round(7 * 36 * Config.themeScale)

        delegate: MenuRow
        {
            id: networkRow

            required property string name
            required property int    strength
            required property bool   known
            required property bool   secured
            required property bool   changing

            width: ListView.view ? ListView.view.rowWidth : 300
            icon: Icon.wifiLevel(strength)
            text: name
            subtitle: changing ? Tr.tr("common.connecting") : known ? Tr.tr("menu.network.saved") : ""
            trailing: strength + "%"
            trailingIcon: secured && !known ? Icon.userLock : ""
            selected: menuNetwork.passwordFor === networkRow.name
            busy: changing

            onClicked: menuNetwork.activate(networkRow.name)

            MenuRowAction
            {
                visible: networkRow.known
                icon: Icon.trash
                label: Tr.tr("common.forget")
                danger: true
                onClicked: ServiceNetwork.forgetNetwork(networkRow.name)
            }
        }
    }

    Rectangle
    {
        visible: menuNetwork.passwordFor !== ""
        width: parent.width
        height: 34
        radius: Theme.radiusMedium
        color: Theme.colorField
        border.width: 1
        border.color: field.activeFocus ? Theme.text4 : "transparent"

        TextInput
        {
            id: field

            anchors { left: parent.left; right: join.left; leftMargin: 10; rightMargin: 6; verticalCenter: parent.verticalCenter }
            color: Theme.text1
            selectionColor: Theme.colorSelection
            font.family: Theme.fontText
            font.pixelSize: Math.round(12 * Config.themeScale)
            echoMode: TextInput.Password
            clip: true

            onAccepted: menuNetwork.activate(menuNetwork.passwordFor)
            Keys.onEscapePressed: menuNetwork.cancelPassword()

            ShellText
            {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text === ""
                label: Tr.tr("menu.network.passwordFor").arg(menuNetwork.passwordFor)
                color: Theme.text4
                width: field.width
            }
        }

        Rectangle
        {
            id: join

            anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
            width: joinText.implicitWidth + 20
            height: 28
            radius: 14
            color: joinArea.pressed ? Theme.colorPressed : joinArea.containsMouse ? Theme.colorHoverStrong : Theme.colorHover

            ShellText { id: joinText; anchors.centerIn: parent; label: Tr.tr("menu.network.join"); color: Theme.text1 }

            MouseArea
            {
                id: joinArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menuNetwork.activate(menuNetwork.passwordFor)
            }
        }
    }

    MenuLabel { hint: true; visible: menuNetwork.status !== ""; text: menuNetwork.status }
}
