//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick.Effects
import Quickshell.Services.Greetd


// Экран входа bloodyShell для greetd: обои, часы, аватар, поле пароля, выбор сеанса, кнопки питания.
// Папка greeter/ — отдельная конфигурация Quickshell, в ней всё, что нужно; greetd запускает её в cage
// (./setup greetd копирует папку в /usr/share/bloodyShell):
//   qs -p /usr/share/bloodyShell/shell.qml
// Файлы: shell.qml — вход и экран, Widgets.qml — детали (кнопки, поле пароля, тени), Theme.qml — настройки,
// цвета, значки и питание; icons/ — значки. Оформление (акцент, обои, анимации, часы) — из /var/lib/bloodyShell,
// туда его кладёт шелл (ServiceGreeter).
// Без greetd (запуск из сеанса) — предпросмотр: вход не выполняется.
ShellRoot
{
    id: root

    readonly property string stateDir: Quickshell.env("BLOODYSHELL_CONFIG") || "/var/lib/bloodyShell"
    readonly property bool preview: !authenticator.available || Quickshell.env("BLOODYSHELL_GREETER_PREVIEW") === "1"
    property var authenticator: Greetd

    // ---------- пользователи: обычные учётные записи из /etc/passwd ----------
    property var users: []
    property int userIndex: 0
    property bool manualMode: false
    property string manualUsername: ""
    onUserIndexChanged: { clearSecret(); failed = false; }
    onManualModeChanged: { clearSecret(); failed = false; }
    onUsersChanged: if (!authenticating) manualMode = users.length === 0
    readonly property var user: manualMode ? ({ name: manualUsername.trim(), fullName: "", home: "" }) : users.length > 0 ? users[Math.max(0, Math.min(userIndex, users.length - 1))] : null

    FileView
    {
        path: "/etc/passwd"
        printErrors: false
        onLoaded:
        {
            const list = [];
            for (const line of text().split("\n"))
            {
                const f = line.split(":");
                const uid = parseInt(f[2], 10);
                if (f.length < 7 || uid < 1000 || uid >= 60000 || /(nologin|false)$/.test(f[6])) continue;
                list.push({ name: f[0], fullName: (f[4] || "").split(",")[0].trim(), home: f[5] });
            }
            root.users = list;
            root.restoreChoice();
        }
    }
    function avatarOf(u)
    {
        return u && !manualMode ? [root.stateDir + "/avatars/" + u.name, "/var/lib/AccountsService/icons/" + u.name] : [];
    }

    // ---------- сеансы: /usr/share/wayland-sessions ----------
    property var sessions: []
    property int sessionIndex: 0
    readonly property var session: sessions.length > 0 ? sessions[Math.max(0, Math.min(sessionIndex, sessions.length - 1))] : null

    Process
    {
        running: true
        command: ["python3", String(Qt.resolvedUrl("session-data")).replace(/^file:\/\//, "")]
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                try { root.sessions = JSON.parse(text).sessions; root.restoreChoice(); if (!root.sessions.length) root.statusMessage = "No Wayland session found. Install niri first."; }
                catch (error) { root.statusMessage = "Could not discover Wayland sessions"; }
            }
        }
    }

    // ---------- последний выбор (пользователь и сеанс) ----------
    property var remembered: ({})
    FileView
    {
        id: memory
        path: root.stateDir + "/greeter-state.json"
        printErrors: false
        onLoaded: { try { root.remembered = JSON.parse(text()) } catch (e) {} root.restoreChoice() }
    }
    function restoreChoice()
    {
        const u = users.findIndex(x => x.name === remembered.user);
        if (u >= 0) userIndex = u;
        // сеанс: последний, а впервые — niri, если он есть
        const s = sessions.findIndex(x => x.id === (remembered.session || "niri"));
        if (s >= 0) sessionIndex = s;
    }
    function rememberChoice()
    {
        if (preview || !user || !session) return;
        memory.setText(JSON.stringify({ user: user.name, session: session.id }) + "\n");
    }

    // ---------- вход ----------
    property bool busy: false
    property bool leaving: false
    property bool failed: false
    property int failures: 0
    property string pending: ""
    property bool authenticating: false
    property bool awaitingResponse: false
    property bool echoResponse: false
    property string statusMessage: ""
    property var launchSession: null

    signal clearSecret()

    function resetAuthentication()
    {
        pending = "";
        authenticating = false;
        awaitingResponse = false;
        echoResponse = false;
        busy = false;
        leaving = false;
        launchLater.stop();
        launchSession = null;
        clearSecret();
    }

    function cancelAuthentication()
    {
        if (!preview && authenticating) authenticator.cancelSession();
        resetAuthentication();
    }

    function submit(password)
    {
        if (preview || busy || leaving || !user || !user.name || !session) return;
        failed = false;
        statusMessage = "";
        if (awaitingResponse)
        {
            awaitingResponse = false;
            busy = true;
            authenticator.respond(password);
            clearSecret();
            return;
        }
        if (authenticating || authenticator.state !== GreetdState.Inactive) return;
        launchSession = session;
        authenticating = true;
        busy = true;
        pending = password;
        authenticator.createSession(user.name);
        clearSecret();
    }

    Connections
    {
        target: root.authenticator
        function onAuthMessage(message, error, responseRequired, echoResponse)
        {
            if (!root.authenticating) return;
            root.statusMessage = message;
            if (!responseRequired) return;
            if (root.pending !== "" && !echoResponse)
            {
                const response = root.pending;
                root.pending = "";
                root.authenticator.respond(response);
            }
            else
            {
                root.awaitingResponse = true;
                root.echoResponse = echoResponse;
                root.busy = false;
                root.clearSecret();
            }
        }
        function onAuthFailure(message)
        {
            root.resetAuthentication();
            root.failed = true;
            root.statusMessage = message || "Sign-in failed. Please try again.";
            root.failures++;
        }
        function onError(error)
        {
            root.resetAuthentication();
            root.failed = true;
            root.statusMessage = error;
            root.failures++;
        }
        function onReadyToLaunch()
        {
            if (!root.authenticating || root.leaving) return;
            root.pending = "";
            root.clearSecret();
            root.rememberChoice();
            root.leaving = true;
            launchLater.interval = Theme.animationsEnabled ? 460 : 0;
            launchLater.restart();
        }
    }

    function shellQuote(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'"; }

    Timer
    {
        id: launchLater
        onTriggered:
        {
            const s = root.launchSession;
            if (root.preview || !root.authenticating || !s) return;
            const command = ["sh", "-c", 'setterm --term linux --clear all --cursor off 2>/dev/null; exec systemd-cat -t "$0" "$@"', s.id].concat(s.command);
            root.authenticator.launch(command.map(root.shellQuote),
                ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + s.id, "XDG_CURRENT_DESKTOP=" + (s.desktop || s.id)], true);
        }
    }

    // ---------- окно ----------
    // cage не умеет layer-shell — обычное окно, cage сам разворачивает его на весь экран
    FloatingWindow
    {
        color: "black"
        fullscreen: !root.preview
        implicitWidth: 1280
        implicitHeight: 800

        Item
        {
            id: screen
            Keys.onEscapePressed: root.cancelAuthentication()
            anchors.fill: parent

            // ---------- появление и уход (каскадом, как у экрана блокировки) ----------
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

            // ---------- обои: размытые и приглушённые; уходя, чуть приближаются и темнеют ----------
            Item
            {
                id: backdrop
                anchors.fill: parent
                property real appear: screen.introBack
                property real leave: screen.outro

                // размывается уже обрезанная по экрану картинка (слой), а не исходная текстура целиком
                Item
                {
                    id: wallpaper
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Image
                    {
                        id: wallImage
                        anchors.fill: parent
                        source: Theme.wallpaperCurrent !== "" ? "file://" + String(Theme.wallpaperCurrent).replace(/^file:\/\//, "") : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(Math.round(backdrop.width / 2), Math.round(backdrop.height / 2))   // под размытие хватит и половины
                        asynchronous: true
                    }
                }
                MultiEffect
                {
                    anchors.fill: parent
                    source: wallpaper
                    visible: wallImage.status === Image.Ready
                    opacity: backdrop.appear
                    blurEnabled: true
                    blur: 0.55
                    blurMax: 48
                    autoPaddingEnabled: false
                    scale: 1 + 0.04 * backdrop.leave
                }
                Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 + 0.35 * backdrop.leave }
            }

            MouseArea { anchors.fill: parent; onClicked: field.focusInput() }

            // ---------- часы и дата ----------
            Column
            {
                id: clock
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Math.round(parent.height * 0.1) }
                opacity: screen.introTop * screen.shown
                transform: Translate { y: (1 - screen.introTop) * -screen.rise - screen.outro * 20 }

                readonly property date now: minuteClock.date
                SystemClock { id: minuteClock; precision: SystemClock.Minutes }

                spacing: 4
                layer.enabled: true
                layer.effect: Widgets.TextShadow {}

                Text
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.now, Theme.widgetClock24 ? "HH:mm" : "h:mm")
                    color: "#ffffff"
                    font.family: Theme.fontText
                    font.pixelSize: 96
                    font.weight: Font.Bold
                }
                Text
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: { const s = clock.now.toLocaleDateString(Qt.locale("en_US"), "dddd, d MMMM"); return s.charAt(0).toUpperCase() + s.slice(1) }
                    color: Theme.text1
                    font.family: Theme.fontText
                    font.pixelSize: 18
                }
            }

            // ---------- вход: аватар со стрелками по бокам, имя, поле пароля, сеанс ----------
            Column
            {
                id: login

                anchors.centerIn: parent
                anchors.verticalCenterOffset: 60
                width: 340
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

                // аватар; пользователей несколько — стрелки слева и справа
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
                        enabled: !root.authenticating && root.userIndex > 0
                        onClicked: root.userIndex--
                    }

                    Widgets.Shadow { target: avatar }

                    ClippingRectangle
                    {
                        id: avatar
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 104
                        height: width
                        radius: width / 2
                        color: Theme.surface
                        border.width: 2
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
                            // первый файл, который откроется: копия от шелла или AccountsService
                            property int attempt: 0
                            readonly property var candidates: root.avatarOf(root.user)
                            anchors.fill: parent
                            source: attempt < candidates.length ? "file://" + candidates[attempt] : ""
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
                        enabled: !root.authenticating && root.userIndex < root.users.length - 1
                        onClicked: root.userIndex++
                    }
                }

                // имя (и логин под ним, если есть полное имя)
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
                        size: 20
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
                    plain: root.echoResponse
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

                // сеанс: ‹ niri ›
                Row
                {
                    visible: root.sessions.length > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Widgets.Button { size: 28; iconSize: 14; anchors.verticalCenter: parent.verticalCenter; icon: Theme.icon("chevron_left"); enabled: !root.authenticating && root.sessionIndex > 0; onClicked: root.sessionIndex-- }
                    Widgets.Label
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(implicitWidth, 120)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.session ? root.session.name : ""
                        layer.enabled: true
                        layer.effect: Widgets.TextShadow {}
                        size: 13
                        color: "#ffffff"
                    }
                    Widgets.Button { size: 28; iconSize: 14; anchors.verticalCenter: parent.verticalCenter; icon: Theme.icon("chevron_right"); enabled: !root.authenticating && root.sessionIndex < root.sessions.length - 1; onClicked: root.sessionIndex++ }
                }
            }

            // ---------- низ: питание ----------
            Row
            {
                anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
                spacing: 8
                opacity: screen.introFoot * screen.shown
                transform: Translate { y: (1 - screen.introFoot) * screen.rise + screen.outro * 16 }

                Widgets.Button { icon: Theme.icon("sleep");    enabled: !root.preview; onClicked: Theme.power("suspend") }
                Widgets.Button { icon: Theme.icon("reboot");   enabled: !root.preview; onClicked: Theme.power("reboot") }
                Widgets.Button { icon: Theme.icon("poweroff"); enabled: !root.preview; onClicked: Theme.power("poweroff") }
            }
        }
    }
}
