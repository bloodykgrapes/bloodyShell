pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../common"
import "../core"

Singleton
{
    id: serviceUser

    property string user: Quickshell.env("USER") || "user"
    property string fullName: ""
    property string homeDirectory: Quickshell.env("HOME") || ""
    property string loginShell: Quickshell.env("SHELL") || ""
    property string uid: ""
    property string gid: ""
    property var groups: []
    property string primaryGroup: ""
    property string avatar: ""
    property string gecosSuffix: ""

    property var accounts: []
    property var groupCatalog: []
    property var shells: []
    property string usermodCommand: ""
    property string pkexecCommand: ""

    property bool loading: false
    property bool applying: false
    readonly property bool avatarBusy: applying
    readonly property bool busy: loading || applying
    property bool accountLoaded: false
    property bool groupsLoaded: false
    property bool avatarLoaded: false
    property bool catalogLoaded: false
    property bool shellsLoaded: false
    property bool toolsLoaded: false
    readonly property bool loaded: accountLoaded && groupsLoaded && avatarLoaded && catalogLoaded && shellsLoaded && toolsLoaded

    property string message: ""
    property string error: ""
    property var draft: ({})
    property var baseline: ({})
    property var pending: null
    property var approved: null
    property bool resetAfterRefresh: false
    readonly property bool confirming: pending !== null
    readonly property var confirmationChanges: pending ? pending.changes : []
    readonly property bool hasChanges: Object.keys(baseline).length > 0 && JSON.stringify(normalize(draft)) !== JSON.stringify(baseline)
    readonly property string avatarPreview: draft.avatarAction === "replace" ? draft.avatarPath : draft.avatarAction === "reset" ? "" : avatar

    function normalize(values)
    {
        return {
            fullName: String(values.fullName || "").trim(),
            username: String(values.username || "").trim(),
            uid: String(values.uid || "").trim(),
            gid: String(values.gid || "").trim(),
            homeDirectory: String(values.homeDirectory || "").trim(),
            loginShell: String(values.loginShell || "").trim(),
            groups: String(values.groups || "").split(/[,\s]+/).filter(Boolean).filter((v, i, all) => all.indexOf(v) === i).sort().join(","),
            avatarAction: values.avatarAction || "keep",
            avatarPath: values.avatarAction === "replace" ? String(values.avatarPath || "") : ""
        };
    }

    function snapshot()
    {
        return normalize({ fullName: fullName, username: user, uid: uid, gid: gid,
            homeDirectory: homeDirectory, loginShell: loginShell,
            groups: groups.filter(g => g !== primaryGroup).join(","), avatarAction: "keep" });
    }

    function resetDraft()
    {
        if (busy || !loaded) return;
        baseline = snapshot();
        draft = Object.assign({}, baseline);
        pending = null;
        error = "";
    }

    function edit(key, value)
    {
        if (busy || !loaded || !Object.prototype.hasOwnProperty.call(baseline, key)) return;
        pending = null;
        const next = Object.assign({}, draft);
        next[key] = value;
        draft = next;
        message = "";
        error = "";
    }

    function refresh()
    {
        if (busy) return;
        pending = null;
        loading = true;
        accountLoaded = false;
        groupsLoaded = false;
        avatarLoaded = false;
        catalogLoaded = false;
        shellsLoaded = false;
        toolsLoaded = false;
        groupFile.reload();
        shellFile.reload();
        if (!toolsProbe.running) toolsProbe.running = true;
        passwdFile.reload();
    }

    function readAccount(text)
    {
        accounts = text.split("\n").filter(l => l !== "" && !l.startsWith("#")).map(l => l.split(":"));
        const fields = accounts.find(f => f[0] === user);
        accountLoaded = !!fields;
        if (!fields)
        {
            loading = false;
            applying = false;
            error = Tr.tr("service.user.localAccountRequired");
            return;
        }
        const gecos = fields[4] || "";
        fullName = gecos.split(",")[0].trim();
        gecosSuffix = gecos.includes(",") ? gecos.substring(gecos.indexOf(",")) : "";
        uid = fields[2];
        gid = fields[3];
        homeDirectory = fields[5];
        loginShell = fields[6] || "";
        primaryGroup = (groupCatalog.find(g => g.gid === gid) || {}).name || "";
        groupsReader.run(["id", "-Gn", "--", user]);
        avatarReader.run(["sh", "-c", 'for f in "$1/.face" "$1/.face.icon" "/var/lib/AccountsService/icons/$2"; do if [ -r "$f" ]; then printf "%s" "$f"; break; fi; done; exit 0', "bloodyShell-avatar", homeDirectory, user]);
    }

    function finishRefresh()
    {
        if (!loading || !loaded) return;
        loading = false;
        const keepDraft = hasChanges && !resetAfterRefresh;
        if (!keepDraft || applying) baseline = snapshot();
        if (!keepDraft) draft = Object.assign({}, baseline);
        resetAfterRefresh = false;
        applying = false;
    }

    function validPath(path)
    {
        return path.startsWith("/") && path !== "/" && !/[\x00-\x1f\x7f:]/.test(path) && !path.split("/").some(p => p === "." || p === "..");
    }

    function validationError(values)
    {
        if (!loaded) return Tr.tr("service.user.loading");
        if (JSON.stringify(snapshot()) !== JSON.stringify(baseline)) return Tr.tr("service.user.externalChanges");
        if (/[\x00-\x1f\x7f:,]/.test(values.fullName)) return Tr.tr("service.user.invalidDisplayName");
        if (values.username !== baseline.username)
        {
            if (!/^[a-zA-Z_][a-zA-Z0-9_-]{0,30}\$?$/.test(values.username)) return Tr.tr("service.user.invalidUsername");
            if (accounts.some(a => a[0] === values.username && a[0] !== user)) return Tr.tr("service.user.usernameTaken");
        }
        if (values.uid !== baseline.uid)
        {
            if (!/^[0-9]+$/.test(values.uid) || Number(values.uid) < 1 || Number(values.uid) > 4294967294) return Tr.tr("service.user.invalidUid");
            if (accounts.some(a => a[0] !== user && Number(a[2]) === Number(values.uid))) return Tr.tr("service.user.uidTaken");
        }
        if (values.gid !== baseline.gid && (!/^[0-9]+$/.test(values.gid) || !groupCatalog.some(g => Number(g.gid) === Number(values.gid)))) return Tr.tr("service.user.invalidGid");
        if (values.homeDirectory !== baseline.homeDirectory && !validPath(values.homeDirectory)) return Tr.tr("service.user.invalidHome");
        if (values.loginShell !== baseline.loginShell && !shells.includes(values.loginShell)) return Tr.tr("service.user.invalidShell");
        if (values.groups !== baseline.groups && values.groups.split(",").filter(Boolean).some(name => !groupCatalog.some(g => g.name === name))) return Tr.tr("service.user.invalidGroups");
        if (!["keep", "replace", "reset"].includes(values.avatarAction)) return Tr.tr("service.user.localImageRequired");
        if (values.avatarAction === "replace" && (!validPath(values.avatarPath) || !/\.(png|jpe?g|webp|bmp|gif)$/i.test(values.avatarPath))) return Tr.tr("service.user.invalidImageFormat");
        if (accountArguments(values).length > 0 && (!usermodCommand || !pkexecCommand)) return Tr.tr("service.user.toolsMissing");
        return "";
    }

    function accountArguments(values)
    {
        const args = [];
        if (values.fullName !== baseline.fullName) args.push("--comment", values.fullName + gecosSuffix);
        if (values.username !== baseline.username) args.push("--login", values.username);
        if (values.uid !== baseline.uid) args.push("--uid", values.uid);
        if (values.gid !== baseline.gid) args.push("--gid", values.gid);
        if (values.homeDirectory !== baseline.homeDirectory) args.push("--home", values.homeDirectory, "--move-home");
        if (values.loginShell !== baseline.loginShell) args.push("--shell", values.loginShell);
        if (values.groups !== baseline.groups) args.push("--groups", values.groups);
        return args;
    }

    function prepareApply()
    {
        if (busy || !hasChanges) return;
        const values = normalize(draft);
        error = validationError(values);
        if (error !== "") { pending = null; return; }
        const fields = [
            ["fullName", "settings.user.displayName"], ["username", "settings.user.username"],
            ["uid", "settings.user.userId"], ["gid", "settings.user.primaryGroupId"],
            ["homeDirectory", "settings.user.homeDirectory"], ["loginShell", "settings.user.loginShell"],
            ["groups", "settings.user.supplementaryGroups"]
        ];
        const changes = fields.filter(f => values[f[0]] !== baseline[f[0]])
            .map(f => ({ label: Tr.tr(f[1]), before: baseline[f[0]], after: values[f[0]] }));
        if (values.avatarAction !== "keep") changes.push({ label: Tr.tr("settings.user.profilePicture"), before: avatar,
            after: values.avatarAction === "replace" ? values.avatarPath : Tr.tr("settings.user.resetPicture") });
        pending = { values: values, changes: changes };
        message = "";
    }

    function cancelApply() { if (!applying) pending = null }

    function confirmApply()
    {
        if (busy || !pending) return;
        const values = pending.values;
        error = validationError(values);
        if (error !== "") { pending = null; return; }
        approved = Object.assign({}, values);
        pending = null;
        applying = true;
        const args = accountArguments(approved);
        if (args.length > 0) accountWriter.run([pkexecCommand, usermodCommand].concat(args, ["--", user]));
        else applyAvatar();
    }

    function applyAvatar()
    {
        if (approved.avatarAction === "replace") avatarWriter.run(["cp", "--", approved.avatarPath, homeDirectory + "/.face"]);
        else if (approved.avatarAction === "reset") avatarWriter.run(["rm", "-f", "--", homeDirectory + "/.face"]);
        else finishApply(true, "");
    }

    function finishApply(success, detail)
    {
        resetAfterRefresh = success;
        if (success) message = approved && accountArguments(approved).length > 0
            ? Tr.tr("service.user.signInAgain") : Tr.tr("service.user.changesApplied");
        else error = detail || Tr.tr("service.user.applyFailed");
        approved = null;

        loading = true;
        accountLoaded = false;
        groupsLoaded = false;
        avatarLoaded = false;
        passwdFile.reload();
    }

    function setAvatar(url)
    {
        if (busy || !loaded) return;
        let path = String(url || "");
        if (path.startsWith("file://"))
        {
            try { path = decodeURIComponent(path.substring(7)) }
            catch (e) { error = Tr.tr("service.user.localImageRequired"); return; }
        }
        if (!validPath(path)) { error = Tr.tr("service.user.localImageRequired"); return; }
        if (path === homeDirectory + "/.face")
        {
            edit("avatarAction", "keep");
            edit("avatarPath", "");
            return;
        }
        if (!/\.(png|jpe?g|webp|bmp|gif)$/i.test(path)) { error = Tr.tr("service.user.invalidImageFormat"); return; }
        edit("avatarAction", "replace");
        edit("avatarPath", path);
    }

    function resetAvatar()
    {
        edit("avatarAction", "reset");
        edit("avatarPath", "");
    }

    function setAvatarPath(path)
    {
        avatar = "";
        Qt.callLater(() => serviceUser.avatar = path || "");
    }

    FileView
    {
        id: passwdFile
        path: "/etc/passwd"
        printErrors: false
        watchChanges: true
        onFileChanged: serviceUser.refresh()
        onLoaded: serviceUser.readAccount(text())
        onLoadFailed: { serviceUser.loading = false; serviceUser.applying = false; serviceUser.error = Tr.tr("service.user.readFailed") }
    }

    FileView
    {
        id: groupFile
        path: "/etc/group"
        printErrors: false
        onLoaded:
        {
            serviceUser.groupCatalog = text().split("\n").filter(l => l !== "" && !l.startsWith("#")).map(l =>
            {
                const f = l.split(":"); return { name: f[0], gid: f[2] };
            });
            serviceUser.primaryGroup = (serviceUser.groupCatalog.find(g => g.gid === serviceUser.gid) || {}).name || "";
            serviceUser.catalogLoaded = true;
            serviceUser.finishRefresh();
        }
        onLoadFailed: { serviceUser.loading = false; serviceUser.error = Tr.tr("service.user.readFailed") }
    }

    FileView
    {
        id: shellFile
        path: "/etc/shells"
        printErrors: false
        onLoaded:
        {
            serviceUser.shells = text().split("\n").map(l => l.trim()).filter(l => l.startsWith("/"));
            serviceUser.shellsLoaded = true;
            serviceUser.finishRefresh();
        }
        onLoadFailed: { serviceUser.loading = false; serviceUser.error = Tr.tr("service.user.readFailed") }
    }

    CommandProcess
    {
        id: groupsReader
        stdout: StdioCollector { id: groupOutput }
        onCompleted: code =>
        {
            serviceUser.groups = code === 0 ? groupOutput.text.trim().split(/\s+/).filter(Boolean) : [];
            serviceUser.groupsLoaded = code === 0;
            if (code !== 0) { serviceUser.loading = false; serviceUser.applying = false; serviceUser.error = errorMessage(Tr.tr("service.user.readFailed")); }
            serviceUser.finishRefresh();
        }
    }

    CommandProcess
    {
        id: avatarReader
        stdout: StdioCollector { id: avatarOutput }
        onCompleted: code =>
        {
            serviceUser.setAvatarPath(code === 0 ? avatarOutput.text.trim() : "");
            serviceUser.avatarLoaded = true;
            serviceUser.finishRefresh();
        }
    }

    Process
    {
        id: toolsProbe
        running: true
        command: ["sh", "-c", 'for name in usermod pkexec; do path=$(command -v "$name" 2>/dev/null || true); printf "%s=%s\\n" "$name" "$path"; done']
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const paths = {};
                for (const line of text.split("\n")) { const i = line.indexOf("="); if (i > 0) paths[line.substring(0, i)] = line.substring(i + 1); }
                serviceUser.usermodCommand = paths.usermod || "";
                serviceUser.pkexecCommand = paths.pkexec || "";
                serviceUser.toolsLoaded = true;
                serviceUser.finishRefresh();
            }
        }
    }

    CommandProcess
    {
        id: accountWriter
        onCompleted: code =>
        {
            if (code !== 0)
            {
                const detail = code === 126 ? Tr.tr("service.user.authorizationCancelled")
                    : /currently used|logged in|process/i.test(errorText) ? Tr.tr("service.user.sessionActive")
                    : errorMessage(Tr.tr("service.user.applyFailed"));
                serviceUser.finishApply(false, detail);
                return;
            }
            serviceUser.user = serviceUser.approved.username;
            serviceUser.homeDirectory = serviceUser.approved.homeDirectory;
            Qt.callLater(() => serviceUser.applyAvatar());
        }
    }

    CommandProcess
    {
        id: avatarWriter
        onCompleted: code => serviceUser.finishApply(code === 0, errorMessage(Tr.tr("service.user.pictureUpdateFailed")))
    }

    Component.onCompleted: refresh()
}
