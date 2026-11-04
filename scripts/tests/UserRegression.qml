import QtQuick
import Quickshell
import Quickshell.Io

import "core"
import "services"

ShellRoot
{
    id: tests
    property int phase: 0
    property string home: Quickshell.env("BLOODYSHELL_TEST_HOME")
    property string newName: 'New "$(touch should-not-exist)"'

    function check(condition, message)
    {
        if (!condition)
        {
            console.error("REGRESSION_FAILED", message);
            Qt.quit();
            throw new Error(message);
        }
    }

    function begin()
    {
        check(ServiceUser.pkexecCommand === Quickshell.env("BLOODYSHELL_TEST_BIN") + "/pkexec", "only the test authorizer may execute");
        check(ServiceUser.usermodCommand === Quickshell.env("BLOODYSHELL_TEST_BIN") + "/usermod", "only the test account tool may execute");
        check(ServiceUser.draft.fullName === "Tester" && !ServiceUser.hasChanges, "initial draft matches account");
        check(ServiceUser.draft.groups === "wheel", "primary group excluded from editable supplementary groups");
        ServiceUser.edit("groups", " wheel, wheel  ");
        check(!ServiceUser.hasChanges, "group whitespace and duplicate entries do not create changes");
        ServiceUser.edit("uid", "0");
        ServiceUser.prepareApply();
        check(!ServiceUser.confirming && ServiceUser.error === "service.user.invalidUid", "invalid UID blocked before confirmation");
        ServiceUser.resetDraft();
        ServiceUser.edit("groups", "unknown-group");
        ServiceUser.prepareApply();
        check(!ServiceUser.confirming && ServiceUser.error === "service.user.invalidGroups", "unknown group rejected");
        ServiceUser.resetDraft();
        ServiceUser.edit("loginShell", "/not/a/shell");
        ServiceUser.prepareApply();
        check(ServiceUser.error === "service.user.invalidShell", "unlisted shell rejected");
        ServiceUser.resetDraft();
        ServiceUser.edit("username", "occupied");
        ServiceUser.prepareApply();
        check(ServiceUser.error === "service.user.usernameTaken", "duplicate username rejected");
        ServiceUser.resetDraft();
        ServiceUser.edit("fullName", "invalid:name");
        ServiceUser.prepareApply();
        check(ServiceUser.error === "service.user.invalidDisplayName", "passwd delimiter rejected");
        ServiceUser.resetDraft();
        ServiceUser.edit("fullName", "Unconfirmed");
        ServiceUser.prepareApply();
        check(ServiceUser.confirming && !ServiceUser.applying, "Apply only opens confirmation");
        ServiceUser.edit("fullName", "Edited after preview");
        check(!ServiceUser.confirming, "editing invalidates frozen confirmation");
        ServiceUser.confirmApply();
        check(!ServiceUser.applying, "cannot apply without confirmation");
        ServiceUser.resetDraft();
        ServiceUser.setAvatar("file://" + home + "/new.png");
        check(ServiceUser.avatarPreview === home + "/new.png", "avatar selection only changes preview");
        ServiceUser.edit("fullName", newName);
        ServiceUser.edit("loginShell", "/bin/bash");
        ServiceUser.edit("groups", "audio");
        ServiceUser.prepareApply();
        check(ServiceUser.confirmationChanges.length === 4, "confirmation lists every changed field including avatar");
        ServiceUser.cancelApply();
        check(!ServiceUser.confirming && ServiceUser.hasChanges, "cancel preserves draft without applying");
        ServiceUser.prepareApply();
        phase = 1;
        ServiceUser.confirmApply();
    }

    Timer
    {
        interval: 25
        running: true
        repeat: true
        onTriggered:
        {
            if (!ServiceUser.loaded || ServiceUser.busy) return;
            if (tests.phase === 0) { tests.begin(); return; }
            if (tests.phase === 1)
            {
                tests.check(ServiceUser.fullName === tests.newName, "account data refreshed after save");
                tests.check(ServiceUser.loginShell === "/bin/bash" && ServiceUser.draft.groups === "audio", "shell and group changes persisted");
                tests.check(!ServiceUser.hasChanges && !ServiceUser.confirming, "successful apply resets draft");
                tests.check(ServiceUser.avatar === tests.home + "/.face", "avatar copied only after confirmation");
                ServiceUser.edit("fullName", "Denied");
                ServiceUser.prepareApply();
                tests.phase = 2;
                ServiceUser.confirmApply();
                return;
            }
            if (tests.phase === 2)
            {
                tests.check(ServiceUser.error === "service.user.authorizationCancelled", "authorization cancellation reported");
                tests.check(ServiceUser.fullName === tests.newName && ServiceUser.hasChanges, "failed apply keeps draft and authoritative account");
                ServiceUser.resetDraft();
                ServiceUser.edit("fullName", "Partial");
                ServiceUser.setAvatar("file://" + tests.home + "/missing.png");
                ServiceUser.prepareApply();
                tests.phase = 3;
                ServiceUser.confirmApply();
                return;
            }
            if (tests.phase === 3)
            {
                tests.check(ServiceUser.fullName === "Partial", "successful account update survives avatar failure");
                tests.check(ServiceUser.error !== "" && ServiceUser.hasChanges, "partial failure reports error and retains remaining draft");
                tests.check(ServiceUser.accountArguments(ServiceUser.normalize(ServiceUser.draft)).length === 0, "retry does not repeat already successful account changes");
                ServiceUser.resetDraft();
                ServiceUser.edit("fullName", "Unapplied");
                ServiceUser.fullName = "External update";
                ServiceUser.prepareApply();
                tests.check(ServiceUser.error === "service.user.accountChangedExternally" && !ServiceUser.confirming, "external account changes invalidate a stale draft");
                console.log("REGRESSIONS_PASSED user editor");
                Qt.quit();
            }
        }
    }
    Timer { interval: 8000; running: true; onTriggered: { console.error("REGRESSION_FAILED user editor timeout", ServiceUser.loaded, ServiceUser.busy, ServiceUser.error); Qt.quit(); } }
}
