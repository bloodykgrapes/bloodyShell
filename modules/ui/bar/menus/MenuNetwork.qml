pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Networking

import "../../../src/ModelSync.js" as ModelSync
import "../../../common"
import "../../../core"
import "../../../services"

Menu
{
    id: menuNetwork

    implicitWidth: 320

    property string passwordFor: ""
    property string lastRequested: ""
    property string status: ""

    Component.onCompleted:
    {
        updateScanning();
        ServiceNetwork.refreshAddress();
        syncNetworks();
    }
    Component.onDestruction:
    {
        ServiceNetwork.setScanning(menuNetwork, false);
        MenuState.menuKeyboard = false;
    }

    onActiveChanged: updateScanning()

    function updateScanning()
    {
        ServiceNetwork.setScanning(menuNetwork, active && ServiceNetwork.hasWiFi && ServiceNetwork.enabledWiFi && ServiceNetwork.enabledWiFiHardware);
    }

    function showCredentials(name, enterprise)
    {
        passwordFor = name;
        credentials.reset();
        credentials.enterprise = enterprise;
        MenuState.menuKeyboard = true;
        if (enterprise) ServiceNetwork.inspectEnterprise(name);
        Qt.callLater(() => credentials.grabFocus());
    }

    function activate(name)
    {
        status = "";
        lastRequested = name;
        const typed = passwordFor === name ? credentials.password : undefined;
        const result = ServiceNetwork.connectNetwork(name, typed, credentials.username, credentials.options);
        if (result === "password" || result === "credentials")
        {
            showCredentials(name, result === "credentials");
            return;
        }
        if (result === "settings") status = Tr.tr("menu.network.unsupportedSecurity");
        if (result === "unavailable") status = Tr.tr("menu.network.outOfRange");
        if (result === "connecting" && credentials.enterprise && passwordFor === name) { credentials.clearSecret(); return; }
        if (result !== "busy") cancelPassword();
    }

    function cancelPassword()
    {
        passwordFor = "";
        credentials.reset();
        MenuState.menuKeyboard = false;
    }

    RevealSection
    {
        shown: menuNetwork.presented
        order: 0

        MenuToggle
        {
            icon: ServiceNetwork.enabledWiFi ? Icon.networkWiFiON : Icon.networkWiFiOFF
            text: Tr.tr("menu.network.wifi")

            enabled: ServiceNetwork.hasWiFi && ServiceNetwork.enabledWiFiHardware
            checked: ServiceNetwork.enabledWiFi

            onToggle: value => ServiceNetwork.setWifiEnabled(value)
        }

        MenuRow
        {
            readonly property var network: ServiceNetwork.wired ? ServiceNetwork.wired.network : null
            visible: ServiceNetwork.hasWired
            prominent: true
            interactive: false
            icon: Icon.networkEthernet
            text: Tr.tr("menu.network.ethernet")
            subtitle: [ServiceNetwork.connectedEthernet ? Tr.tr("common.connected")
                : ServiceNetwork.wired && ServiceNetwork.wired.hasLink ? Tr.tr("common.notConnected") : Tr.tr("menu.network.cableUnplugged"),
                ServiceNetwork.wired ? ServiceNetwork.wired.name : ""].filter(value => value !== "").join("  ·  ")
            selected: ServiceNetwork.connectedEthernet
            busy: network !== null && network.stateChanging
        }

        MenuSeparator { visible: ServiceNetwork.hasWiFi }

        MenuLabel
        {
            hint: true
            visible: ServiceNetwork.hasWiFi && !ServiceNetwork.enabledWiFi
            text: ServiceNetwork.enabledWiFiHardware ? Tr.tr("menu.network.wifiOff") : Tr.tr("menu.network.wifiBlocked")
        }
    }

    RevealSection
    {
        shown: menuNetwork.presented
        order: 1

        MenuRow
        {
            id: activeConnection

            readonly property var active: ServiceNetwork.enabledWiFi ? ServiceNetwork.wifiList.find(network => network.connected) || null : null
            readonly property int strength: active ? ServiceNetwork.strengthPercent(active.strength) : 0

            visible: active !== null
            prominent: true
            selected: true
            icon: Icon.wifiLevel(strength)
            text: active ? active.name : ""
            subtitle: active && active.stateChanging ? Tr.tr("common.disconnecting")
                : [Tr.tr("common.connected"), ServiceNetwork.wifiAddress, strength + "%"].filter(value => value !== "").join("  ·  ")
            busy: active !== null && active.stateChanging
            onClicked: if (active) menuNetwork.activate(active.name)

            MenuRowAction { icon: Icon.linkOff; label: Tr.tr("common.disconnect"); enabled: !activeConnection.busy; onClicked: ServiceNetwork.disconnectNetwork(ServiceNetwork.ssid) }
            MenuRowAction { icon: Icon.trash; label: Tr.tr("common.forget"); danger: true; enabled: !activeConnection.busy; onClicked: ServiceNetwork.forgetNetwork(ServiceNetwork.ssid) }
        }
    }

    RevealSection
    {
        shown: menuNetwork.presented
        order: 2

        MenuLabel
        {
            visible: ServiceNetwork.hasWiFi && ServiceNetwork.enabledWiFi
            text: Tr.tr("menu.network.networks")
            actionText: ServiceNetwork.refreshing ? Tr.tr("common.refreshing") : Tr.tr("common.refresh")
            actionIcon: Icon.reload
            actionEnabled: ServiceNetwork.enabledWiFiHardware && !ServiceNetwork.refreshing
            onActionTriggered: ServiceNetwork.refreshNetworks()
        }

        MenuLabel
        {
            hint: true
            visible: ServiceNetwork.enabledWiFi && networks.count === 0
            text: ServiceNetwork.refreshing ? Tr.tr("menu.network.scanning") : Tr.tr("menu.network.noNetworks")
        }
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
        if (passwordFor !== "" && !list.some(network => network.name === passwordFor)) cancelPassword();
    }

    Connections
    {
        target: ServiceNetwork
        function onCredentialsRequired(name, enterprise)
        {
            if (menuNetwork.visible && name === menuNetwork.lastRequested) menuNetwork.showCredentials(name, enterprise);
        }
        function onConnectionFinished(name, success, message)
        {
            if (!menuNetwork.visible || name !== menuNetwork.lastRequested) return;
            menuNetwork.status = message;
            if (success) menuNetwork.cancelPassword();
            else credentials.clearSecret();
        }
        function onRefreshErrorChanged() { if (ServiceNetwork.refreshError !== "") menuNetwork.status = ServiceNetwork.refreshError; }
        function onRefreshingChanged() { if (ServiceNetwork.refreshing) menuNetwork.status = ""; }
        function onWifiListChanged()  { menuNetwork.syncNetworks() }
        function onEnabledWiFiChanged() { menuNetwork.updateScanning(); menuNetwork.syncNetworks() }
        function onEnabledWiFiHardwareChanged() { menuNetwork.updateScanning() }
        function onHasWiFiChanged() { menuNetwork.updateScanning() }
    }

    RevealSection
    {
        shown: menuNetwork.presented
        order: 3

        MenuList
        {
            model: networks
            opening: menuNetwork.opening

            maxHeight: Math.round((menuNetwork.passwordFor !== "" ? 3 : 7) * 36 * Config.themeScale)

            delegate: MenuRow
            {
                id: networkRow

                required property string name
                required property int    strength
                required property bool   known
                required property bool   secured
                required property bool   changing

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
    }

    RevealSection
    {
        shown: menuNetwork.presented
        order: 4

        WifiCredentials
        {
            id: credentials
            visible: menuNetwork.passwordFor !== ""
            width: parent.width
            busy: ServiceNetwork.authBusy
            details: ServiceNetwork.authNetwork === menuNetwork.passwordFor ? ServiceNetwork.authDetails : ({ profile: false })
            onSubmitted: menuNetwork.activate(menuNetwork.passwordFor)
            onCancelled: menuNetwork.cancelPassword()
        }

        MenuLabel { hint: true; visible: menuNetwork.status !== ""; text: menuNetwork.status }
    }
}
