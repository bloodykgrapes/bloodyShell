import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects

Item
{
    id: root
    implicitWidth: 1280
    implicitHeight: 800

    property var authenticator: typeof sddm === "undefined" ? null : sddm
    property var accountModel: typeof userModel === "undefined" ? null : userModel
    property var desktopModel: typeof sessionModel === "undefined" ? null : sessionModel
    readonly property bool preview: authenticator === null
    readonly property string stateDir: Theme.stateDir
    property bool keyboardVisible: false
    property var keyboardEngine: null
    readonly property var activeKeyboardEngine: keyboardEngine || nativeKeyboard.item
    property int keyboardLayoutIndex: 0
    readonly property var keyboardLayouts: Theme.keyboardLayouts
    property real keyboardReveal: keyboardVisible && !leaving ? 1 : 0
    Behavior on keyboardReveal { enabled: Theme.animationsEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    Loader
    {
        id: nativeKeyboard
        active: (root.keyboardVisible || root.keyboardReveal > 0.001) && !root.keyboardEngine
        source: "native/Engine.qml"
        onLoaded: item.local = true
    }

    function rows(model, roles)
    {
        if (!model) return [];
        const result = [];
        for (let row = 0; row < model.count; row++)
        {
            const item = { index: row };
            for (const role of Object.keys(roles))
                item[role] = model.data(model.index(row, 0), Qt.UserRole + roles[role]) || "";
            result.push(item);
        }
        return result;
    }
    readonly property var users: rows(accountModel, { name: 1, fullName: 2, home: 3, icon: 4 })
    property int userIndex: accountModel ? Math.max(0, accountModel.lastIndex) : 0
    property bool manualMode: users.length === 0
    property string manualUsername: accountModel ? accountModel.lastUser : ""
    onUserIndexChanged: { clearSecret(); failed = false; }
    onManualModeChanged: { clearSecret(); failed = false; }
    readonly property var user: manualMode ? ({ name: manualUsername.trim(), fullName: "" })
        : users.length > 0 ? users[Math.max(0, Math.min(userIndex, users.length - 1))] : null
    function avatarOf(u)
    {
        if (!u || manualMode) return [];
        return [u.name === Theme.avatarUser ? stateDir + "/avatars/" + u.name : "", u.icon || ""].filter(path => path !== "");
    }
    readonly property var sessions: rows(desktopModel, { file: 2, name: 4 })
    property int sessionIndex: desktopModel ? Math.max(0, desktopModel.lastIndex) : 0
    readonly property var session: sessions.length > 0 ? sessions[Math.max(0, Math.min(sessionIndex, sessions.length - 1))] : null

    property bool busy: false
    property bool leaving: false
    readonly property bool authenticating: busy || leaving
    property bool failed: false
    property int failures: 0
    property string statusMessage: sessions.length > 0 ? "" : "No session found. Install niri first."
    signal clearSecret()

    function cancelAuthentication()
    {
        clearSecret();
        if (authenticating) return;
        failed = false;
        statusMessage = "";
    }
    function submit(password)
    {
        if (preview || authenticating || !user || !user.name || !session) return;
        busy = true;
        failed = false;
        statusMessage = "";
        authenticator.login(user.name, password, session.index);
        clearSecret();
    }
    function power(action)
    {
        if (preview || leaving) return;
        if (action === "suspend" && authenticator.canSuspend) authenticator.suspend();
        else if (action === "reboot" && authenticator.canReboot) authenticator.reboot();
        else if (action === "poweroff" && authenticator.canPowerOff) authenticator.powerOff();
    }
    Connections
    {
        target: root.authenticator
        function onLoginFailed()
        {
            root.busy = false;
            root.leaving = false;
            root.failed = true;
            root.statusMessage = "Sign-in failed. Please try again.";
            root.failures++;
            root.clearSecret();
        }
        function onLoginSucceeded() { root.clearSecret(); root.leaving = true; }
        function onInformationMessage(message) { root.statusMessage = message; }
    }

    Rectangle { anchors.fill: parent; color: "black" }
    Item
    {
        id: screen
        Keys.onEscapePressed: root.cancelAuthentication()
        anchors.fill: parent

        property real intro: Theme.animationsEnabled ? 0 : 1
        function phase(from, length) { return Math.max(0, Math.min(1, (intro - from) / length)) }
        readonly property real introBack: phase(0.0, 0.7)
        readonly property real introTop:  phase(0.1, 0.55)
        readonly property real introMain: phase(0.22, 0.55)
        readonly property real introFoot: phase(0.38, 0.55)
        readonly property real rise: Theme.animationsFluid ? 26 : 12

        NumberAnimation
        {
            id: introAnim
            target: screen; property: "intro"; from: 0; to: 1
            duration: Theme.animationsFluid ? 1100 : 700
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingEmphasized
        }
        Component.onCompleted: if (Theme.animationsEnabled) introAnim.start()

        property real outro: root.leaving ? 1 : 0
        Behavior on outro { enabled: Theme.animationsEnabled; NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easingAccelerate } }
        readonly property real shown: 1 - outro

        Item
        {
            id: backdrop
            anchors.fill: parent
            property real appear: screen.introBack
            property real leave: screen.outro

            Image
            {
                anchors.fill: parent
                source: Theme.wallpaperCurrent !== "" ? "file://" + String(Theme.wallpaperCurrent).replace(/^file:\/\//, "") : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(Math.round(backdrop.width), Math.round(backdrop.height))
                asynchronous: true
                opacity: backdrop.appear
                scale: 1 + 0.04 * backdrop.leave
            }
            Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 + 0.35 * backdrop.leave }
        }

        MouseArea { anchors.fill: parent; onClicked: field.focusInput() }

        Item
        {
            id: contentArea
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top; margins: 24 }

            Column
            {
                id: content
                objectName: "greeterContent"
                anchors.centerIn: parent
                width: 360
                spacing: 30
                scale: Math.max(0.1, Math.min(1, contentArea.width / width, contentArea.height / implicitHeight))

                Column
                {
                    id: clock
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    spacing: 0
                    layer.enabled: true
                    layer.effect: Widgets.TextShadow {}
                    opacity: screen.introTop * screen.shown
                    transform: Translate { y: (1 - screen.introTop) * -screen.rise - screen.outro * 20 }
                    readonly property date now: minuteClock.date
                    QtObject { id: minuteClock; property date date: new Date() }
                    Timer
                    {
                        interval: 60000 - Date.now() % 60000
                        running: true
                        onTriggered: { minuteClock.date = new Date(); interval = 60000 - Date.now() % 60000; restart(); }
                    }

                    Text
                    {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: { const date = clock.now.toLocaleDateString(Theme.locale, "dddd, d MMMM"); return date.charAt(0).toUpperCase() + date.slice(1) }
                        color: "#e2e2e7"
                        font.family: Theme.fontText
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        font.letterSpacing: 0.5
                    }
                    Text
                    {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatTime(clock.now, Theme.widgetClock24 ? "HH:mm" : "h:mm")
                        color: "#ffffff"
                        font.family: Theme.fontText
                        font.pixelSize: 104
                        font.weight: Font.DemiBold
                        font.letterSpacing: -4
                    }
                    Text
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !Theme.widgetClock24
                        text: Qt.formatTime(clock.now, "AP")
                        color: Theme.text2
                        font.family: Theme.fontText
                        font.pixelSize: 12
                        font.letterSpacing: 2
                    }
                }

                Column
                {
                    id: login

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    spacing: 14

                    opacity: screen.introMain * screen.shown
                    scale: 1 - 0.04 * screen.outro
                    transform: Translate { id: loginShift; y: (1 - screen.introMain) * screen.rise }

                    SequentialAnimation
                    {
                        id: shake
                        NumberAnimation { target: loginShift; property: "x"; to: -6; duration: 50; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: loginShift; property: "x"; to: 5;  duration: 50 }
                        NumberAnimation { target: loginShift; property: "x"; to: -3; duration: 40 }
                        NumberAnimation { target: loginShift; property: "x"; to: 0;  duration: 40 }
                    }
                    Connections
                    {
                        target: root
                        function onFailuresChanged()
                        {
                            field.clear();
                            field.focusInput();
                            if (Theme.animationsEnabled) shake.restart();
                        }
                    }

                    Item
                    {
                        width: parent.width
                        height: avatar.height

                        Widgets.Button
                        {
                            size: 28; iconSize: 14
                            visible: root.users.length > 1 && !root.manualMode
                            anchors { right: avatar.left; rightMargin: 20; verticalCenter: avatar.verticalCenter }
                            icon: Theme.icon("chevron_left")
                            label: "Previous account"
                            enabled: !root.authenticating && root.userIndex > 0
                            onClicked: root.userIndex--
                        }

                        Widgets.Shadow { target: avatar }

                        Rectangle
                        {
                            id: avatar
                            layer.enabled: true
                            layer.effect: MultiEffect
                            {
                                maskEnabled: true
                                maskSource: Rectangle
                                {
                                    width: avatar.width; height: avatar.height; radius: avatar.radius
                                    color: "white"; layer.enabled: true; visible: false
                                }
                            }
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 88
                            height: width
                            radius: width / 2
                            color: Theme.surface
                            border.width: 1
                            border.color: Theme.colorLine

                            Image
                            {
                                anchors.centerIn: parent
                                visible: face.status !== Image.Ready
                                source: Theme.icon("user")
                                width: Math.round(parent.width * 0.42)
                                height: width
                                sourceSize: Qt.size(width * 2, height * 2)
                            }
                            Image
                            {
                                id: face
                                property int attempt: 0
                                readonly property var candidates: root.avatarOf(root.user)
                                anchors.fill: parent
                                source: attempt < candidates.length ? "file://" + String(candidates[attempt]).replace(/^file:\/\//, "") : ""
                                onCandidatesChanged: attempt = 0
                                onStatusChanged: if (status === Image.Error) attempt++
                                sourceSize: Qt.size(208, 208)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        Widgets.Button
                        {
                            size: 28; iconSize: 14
                            visible: root.users.length > 1 && !root.manualMode
                            anchors { left: avatar.right; leftMargin: 20; verticalCenter: avatar.verticalCenter }
                            icon: Theme.icon("chevron_right")
                            label: "Next account"
                            enabled: !root.authenticating && root.userIndex < root.users.length - 1
                            onClicked: root.userIndex++
                        }
                    }

                    Column
                    {
                        width: parent.width
                        spacing: 2
                        layer.enabled: true
                        layer.effect: Widgets.TextShadow {}

                        Widgets.Label
                        {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.user ? (root.user.fullName || root.user.name) : ""
                            size: 22
                            color: "#ffffff"
                            font.weight: Font.DemiBold
                        }
                        Widgets.Label
                        {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            visible: root.user !== null && root.user.fullName !== ""
                            text: root.user ? "@" + root.user.name : ""
                            size: 12
                            color: Theme.text2
                        }
                    }

                    Controls.TextField
                    {
                        id: manualName
                        width: parent.width
                        height: 44
                        visible: root.manualMode
                        enabled: !root.authenticating
                        text: root.manualUsername
                        placeholderText: "Username"
                        color: Theme.text1
                        placeholderTextColor: Theme.text2
                        font.family: Theme.fontText
                        font.pixelSize: 14
                        leftPadding: 14
                        selectByMouse: true
                        onTextEdited: root.manualUsername = text
                        onAccepted: field.focusInput()
                        background: Rectangle { radius: 14; color: Theme.colorField; border.width: 1; border.color: Theme.colorLine }
                    }

                    Widgets.PasswordField
                    {
                        id: field
                        width: parent.width
                        plain: false
                        busy: root.busy
                        failed: root.failed
                        closed: root.leaving
                        onSubmitted: password => root.submit(password)
                        onEdited: root.failed = false
                        onCancelled: root.cancelAuthentication()
                        Connections { target: root; function onClearSecret() { field.clear(); field.focusInput(); } }
                    }


                    Widgets.Label
                    {
                        width: parent.width
                        text: root.preview ? "Preview · sign-in and power actions disabled" : root.statusMessage
                        visible: text !== ""
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        color: root.failed ? Theme.colorCritical : Theme.text2
                        size: 12
                    }

                    Widgets.Label
                    {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.manualMode ? "Back to accounts" : "Other user"
                        visible: root.users.length > 0
                        opacity: root.authenticating ? 0.4 : 1
                        size: 12
                        MouseArea
                        {
                            anchors.fill: parent
                            enabled: !root.authenticating
                            cursorShape: Qt.PointingHandCursor
                            onClicked:
                            {
                                root.manualMode = !root.manualMode;
                                if (root.manualMode) Qt.callLater(() => manualName.forceActiveFocus());
                            }
                        }
                    }

                    Row
                    {
                        visible: root.sessions.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Widgets.Button { size: 28; iconSize: 14; label: "Previous session"; anchors.verticalCenter: parent.verticalCenter; icon: Theme.icon("chevron_left"); enabled: !root.authenticating && root.sessionIndex > 0; onClicked: root.sessionIndex-- }
                        Widgets.Label
                        {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(220, Math.max(implicitWidth, 120))
                            horizontalAlignment: Text.AlignHCenter
                            text: root.session ? root.session.name : ""
                            layer.enabled: true
                            layer.effect: Widgets.TextShadow {}
                            size: 13
                            color: "#ffffff"
                        }
                        Widgets.Button { size: 28; iconSize: 14; label: "Next session"; anchors.verticalCenter: parent.verticalCenter; icon: Theme.icon("chevron_right"); enabled: !root.authenticating && root.sessionIndex < root.sessions.length - 1; onClicked: root.sessionIndex++ }
                    }
                }
            }
        }

        Row
        {
            id: footer
            objectName: "greeterFooter"
            anchors { right: parent.right; bottom: parent.bottom; margins: 24; bottomMargin: 24 + (onScreenKeyboard.height + 20) * root.keyboardReveal }
            spacing: 8
            opacity: screen.introFoot * screen.shown
            transform: Translate { y: (1 - screen.introFoot) * screen.rise + screen.outro * 16 }

            Widgets.Button
            {
                objectName: "greeterKeyboardButton"
                icon: Theme.icon("keyboard"); label: "On-screen keyboard"
                onClicked: { root.keyboardVisible = !root.keyboardVisible; field.focusInput(); }
            }
            Widgets.Button { icon: Theme.icon("sleep");    label: "Sleep"; enabled: !root.preview && root.authenticator.canSuspend; onClicked: root.power("suspend") }
            Widgets.Button { icon: Theme.icon("reboot");   label: "Restart"; enabled: !root.preview && root.authenticator.canReboot; onClicked: root.power("reboot") }
            Widgets.Button { icon: Theme.icon("poweroff"); label: "Shut down"; enabled: !root.preview && root.authenticator.canPowerOff; onClicked: root.power("poweroff") }
        }

        Loader
        {
            id: onScreenKeyboard
            active: root.keyboardVisible || root.keyboardReveal > 0.001
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(1, Math.min(840, root.width - 32))
            height: item ? item.implicitHeight : 0
            y: root.height - (height + 16) * root.keyboardReveal
            opacity: root.keyboardReveal
            source: Theme.keyboardSource
            onLoaded:
            {
                item.engine = Qt.binding(() => root.activeKeyboardEngine);
                item.status = Qt.binding(() => nativeKeyboard.status === Loader.Error ? item.labels.unavailable : root.activeKeyboardEngine ? root.activeKeyboardEngine.error : item.labels.loading);
                item.layouts = Qt.binding(() => root.keyboardLayouts);
                item.layoutIndex = Qt.binding(() => root.keyboardLayoutIndex);
                item.animations = Qt.binding(() => Theme.animationsEnabled);
                item.fluid = Qt.binding(() => Theme.animationsFluid);
                item.enabled = Qt.binding(() => !root.authenticating);
                item.dismissed.connect(() => { root.keyboardVisible = false; field.focusInput(); });
                item.layoutSelected.connect(index => root.keyboardLayoutIndex = index);
            }
        }
    }
}
