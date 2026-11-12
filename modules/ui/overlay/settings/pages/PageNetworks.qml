pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Networking

import "../../../../src/ModelSync.js" as ModelSync
import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageNetworks

    title: Tr.tr("menu.network.networks")
    subtitle: Tr.tr("settings.networks.description")

    property string passwordFor: ""
    property string lastRequested: ""
    property string forgetFor: ""
    property string status: ""
    property bool scanning: false
    readonly property bool scanningWanted: active && ServiceNetwork.hasWiFi && ServiceNetwork.enabledWiFi && ServiceNetwork.enabledWiFiHardware

    onScanningWantedChanged: updateScanning()
    Component.onCompleted: { updateScanning(); syncNetworks(); ServiceNetwork.refreshAddress() }
    Component.onDestruction: if (scanning) ServiceNetwork.setScanning(pageNetworks, false)

    function updateScanning()
    {
        if (scanning === scanningWanted) return;
        scanning = scanningWanted;
        ServiceNetwork.setScanning(pageNetworks, scanning);
        if (!scanning) { cancelPassword(); forgetFor = ""; }
    }

    function cancelPassword() { passwordFor = ""; credentials.reset() }

    function revealControl(item)
    {
        Qt.callLater(() =>
        {
            const point = item.mapToItem(pageNetworks.contentItem, 0, 0);
            const target = point.y + item.height + 24 > contentY + height
                ? point.y + item.height + 24 - height : point.y < contentY ? point.y : contentY;
            contentY = Math.max(0, Math.min(Math.max(0, contentHeight - height), target));
        });
    }

    function showCredentials(name, enterprise)
    {
        passwordFor = name;
        credentials.reset();
        credentials.enterprise = enterprise;
        if (enterprise) ServiceNetwork.inspectEnterprise(name);
        Qt.callLater(() => credentials.grabFocus());
        revealControl(credentials);
    }

    function activate(name)
    {
        status = "";
        lastRequested = name;
        const secret = passwordFor === name ? credentials.password : undefined;
        const result = ServiceNetwork.connectNetwork(name, secret, credentials.username, credentials.options);
        if (result === "password" || result === "credentials")
        {
            showCredentials(name, result === "credentials");
            return;
        }
        if (result === "settings") status = Tr.tr("menu.network.unsupportedSecurity");
        else if (result === "unavailable") status = Tr.tr("menu.network.outOfRange");
        if (result === "connecting" && credentials.enterprise && passwordFor === name) { credentials.clearSecret(); return; }
        if (result !== "busy") cancelPassword();
    }

    ListModel { id: networks }

    function syncNetworks()
    {
        const seen = {};
        const list = (ServiceNetwork.enabledWiFi ? ServiceNetwork.wifiList : [])
            .filter(network => network.name && !seen[network.name] && (seen[network.name] = true));
        ModelSync.sync(networks, list.map(network => ({
            name: network.name,
            strength: ServiceNetwork.strengthPercent(network.strength),
            connected: network.connected === true,
            known: network.known === true,
            changing: network.stateChanging === true,
            secured: network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe
        })), "name");
        if (passwordFor !== "" && !list.some(network => network.name === passwordFor && !network.connected)) cancelPassword();
        if (forgetFor !== "" && !list.some(network => network.name === forgetFor && network.known)) forgetFor = "";
    }

    Connections
    {
        target: ServiceNetwork
        function onCredentialsRequired(name, enterprise)
        {
            if (pageNetworks.visible && name === pageNetworks.lastRequested) pageNetworks.showCredentials(name, enterprise);
        }
        function onConnectionFinished(name, success, message)
        {
            if (!pageNetworks.visible || name !== pageNetworks.lastRequested) return;
            pageNetworks.status = message;
            if (success) pageNetworks.cancelPassword();
            else credentials.clearSecret();
        }
        function onRefreshErrorChanged() { if (ServiceNetwork.refreshError !== "") pageNetworks.status = ServiceNetwork.refreshError; }
        function onRefreshingChanged() { if (ServiceNetwork.refreshing) pageNetworks.status = ""; }
        function onWifiListChanged() { pageNetworks.syncNetworks() }
        function onEnabledWiFiChanged() { pageNetworks.syncNetworks() }
    }

    SettingsGroup
    {
        title: Tr.tr("common.general")

        SettingsRow
        {
            icon: ServiceNetwork.enabledWiFi ? Icon.networkWiFiON : Icon.networkWiFiOFF
            label: Tr.tr("menu.network.wifi")
            description: !ServiceNetwork.hasWiFi ? Tr.tr("settings.networks.noAdapter")
                : !ServiceNetwork.enabledWiFiHardware ? Tr.tr("menu.network.wifiBlocked")
                : !ServiceNetwork.enabledWiFi ? Tr.tr("menu.network.wifiOff")
                : ServiceNetwork.connectedWiFi ? ServiceNetwork.ssid : Tr.tr("common.notConnected")
            Toggle
            {
                checked: ServiceNetwork.enabledWiFi
                enabled: ServiceNetwork.hasWiFi && ServiceNetwork.enabledWiFiHardware
                onToggled: value => ServiceNetwork.setWifiEnabled(value)
            }
        }
        SettingsRow
        {
            visible: ServiceNetwork.hasWired
            icon: Icon.networkEthernet
            label: Tr.tr("menu.network.ethernet")
            description: ServiceNetwork.wired ? ServiceNetwork.wired.name : ""
            valueText: ServiceNetwork.connectedEthernet ? Tr.tr("common.connected") : Tr.tr("menu.network.cableUnplugged")
        }
    }

    SettingsGroup
    {
        visible: ServiceNetwork.hasWiFi && ServiceNetwork.enabledWiFi && ServiceNetwork.enabledWiFiHardware
        title: Tr.tr("settings.networks.available")
        subtitle: Tr.tr("settings.networks.scanHint")

        SettingsRow
        {
            label: Tr.tr("common.refresh")
            description: ServiceNetwork.refreshing ? Tr.tr("menu.network.scanning") : ""
            SettingsButton
            {
                text: Tr.tr("common.refresh")
                icon: Icon.reload
                enabled: !ServiceNetwork.refreshing
                onClicked: ServiceNetwork.refreshNetworks()
            }
        }
        SettingsRow
        {
            visible: networks.count === 0
            label: ServiceNetwork.refreshing ? Tr.tr("menu.network.scanning") : Tr.tr("menu.network.noNetworks")
        }
        Repeater
        {
            model: networks
            SettingsRow
            {
                id: networkRow
                required property string name
                required property int strength
                required property bool connected
                required property bool known
                required property bool changing
                required property bool secured

                icon: Icon.wifiLevel(strength)
                label: name
                description: [connected ? ServiceNetwork.wifiAddress : "", strength + "%",
                    secured ? Tr.tr("settings.networks.secured") : Tr.tr("settings.networks.open"),
                    known ? Tr.tr("menu.network.saved") : ""].filter(value => value !== "").join(" · ")
                badge: connected ? Tr.tr("common.connected") : ""
                Row
                {
                    spacing: 8
                    SettingsButton
                    {
                        text: networkRow.changing ? Tr.tr("common.working") : networkRow.connected ? Tr.tr("common.disconnect") : Tr.tr("menu.network.join")
                        enabled: !networkRow.changing
                        onClicked: pageNetworks.activate(networkRow.name)
                    }
                    SettingsIconButton
                    {
                        visible: networkRow.known
                        icon: Icon.trash
                        enabled: !networkRow.changing
                        onClicked: { pageNetworks.cancelPassword(); pageNetworks.forgetFor = networkRow.name; }
                    }
                }
            }
        }
    }

    SettingsGroup
    {
        visible: pageNetworks.passwordFor !== ""
        title: credentials.enterprise ? Tr.tr("settings.networks.credentialsFor").arg(pageNetworks.passwordFor) : Tr.tr("menu.network.passwordFor").arg(pageNetworks.passwordFor)
        SettingsRow
        {
            stacked: true
            label: credentials.enterprise ? Tr.tr("settings.networks.credentials") : Tr.tr("common.password")
            WifiCredentials
            {
                id: credentials
                width: parent.width
                busy: ServiceNetwork.authBusy
                details: ServiceNetwork.authNetwork === pageNetworks.passwordFor ? ServiceNetwork.authDetails : ({ profile: false })
                onSubmitted: pageNetworks.activate(pageNetworks.passwordFor)
                onCancelled: pageNetworks.cancelPassword()
            }
        }
    }

    SettingsConfirmation
    {
        objectName: "forgetConfirmation"
        host: pageNetworks
        visible: pageNetworks.active && pageNetworks.forgetFor !== ""
        title: Tr.tr("settings.networks.forgetTitle").arg(pageNetworks.forgetFor)
        description: Tr.tr("settings.networks.forgetHint")
        acceptText: Tr.tr("common.forget")
        danger: true
        onAccepted: { ServiceNetwork.forgetNetwork(pageNetworks.forgetFor); pageNetworks.forgetFor = ""; }
        onRejected: pageNetworks.forgetFor = ""
    }

    SettingsRow
    {
        visible: pageNetworks.status !== ""
        label: Tr.tr("common.status")
        description: pageNetworks.status
    }
}
