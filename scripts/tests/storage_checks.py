#!/usr/bin/env python3

import importlib.machinery
import importlib.util
import stat
import tempfile
from contextlib import ExitStack, nullcontext
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
loader = importlib.machinery.SourceFileLoader("storage_helper", str(ROOT / "scripts/runtime/storage"))
spec = importlib.util.spec_from_loader(loader.name, loader)
storage = importlib.util.module_from_spec(spec)
loader.exec_module(storage)


def transaction(base, failure=""):
    base.mkdir()
    fstab = base / "fstab"
    original = "# Keep existing entries\nUUID=system / ext4 defaults 0 1\n"
    fstab.write_text(original)
    fstab.chmod(0o640)
    target = base / "mountpoint"
    calls = []

    def run(args):
        calls.append(args)
        if args[0] == "findmnt" and "--verify" in args:
            assert Path(args[-1]).read_text().startswith(original)
            if failure == "verify":
                raise RuntimeError("Verification failed")
        elif args[0] == "findmnt":
            return "" if failure == "missing" else "DATA-UUID\n"
        if args[0] == "mount" and failure in ("mount", "external"):
            if failure == "external":
                fstab.write_text("external edit\n")
            raise RuntimeError("Mount failed")
        return ""

    with ExitStack() as stack:
        stack.enter_context(patch.object(storage, "FSTAB", fstab))
        stack.enter_context(patch.object(storage.os, "geteuid", return_value=0))
        stack.enter_context(patch.object(storage, "storage_lock", side_effect=lambda: nullcontext()))
        stack.enter_context(patch.object(storage, "validate_fstab", side_effect=lambda path: path.stat()))
        stack.enter_context(patch.object(storage, "verify_device", return_value=True))
        stack.enter_context(patch.object(storage, "validate_target", return_value=target))
        stack.enter_context(patch.object(storage, "same_device", return_value=False))
        stack.enter_context(patch.object(storage, "reload_mounts"))
        stack.enter_context(patch.object(storage, "run", side_effect=run))
        try:
            storage.mount_persistent("/dev/test", "DATA-UUID", "ext4", "/mnt/My Data")
        except RuntimeError as error:
            assert failure, error
            if failure == "external":
                assert "rollback was skipped" in str(error)
        else:
            assert not failure
    if failure == "external":
        assert fstab.read_text() == "external edit\n"
    elif failure:
        assert fstab.read_text() == original
        assert not target.exists()
    else:
        assert fstab.read_text().startswith(original)
        assert "UUID=DATA-UUID\t/mnt/My\\040Data\text4\tdefaults,nofail,x-systemd.device-timeout=10s,ro\t0\t0\n" in fstab.read_text()
        assert ["mount", "--", "/mnt/My Data"] in calls
        backups = list(base.glob("fstab.bloodyShell-*.bak"))
        assert len(backups) == 1 and backups[0].read_text() == original
        assert stat.S_IMODE(fstab.stat().st_mode) == 0o640


def main():
    assert storage.unescape(storage.escape("/mnt/My Data\\drive")) == "/mnt/My Data\\drive"
    for target in ("/", "/etc/data", "/mnt", "/mnt/../etc", "/mnt/a/b", "/mnt/./data", "/mnt/tab\tname"):
        try:
            storage.validate_target(target)
        except (ValueError, OSError):
            pass
        else:
            raise AssertionError(target)
    with patch.object(storage, "same_device", return_value=False):
        for text in ("UUID=DATA /mnt/old ext4 defaults 0 0\n", "UUID=OTHER /mnt/My\\040Data ext4 defaults 0 0\n"):
            try:
                storage.check_existing(text, "/dev/test", "DATA", "/mnt/My Data")
            except ValueError:
                pass
            else:
                raise AssertionError("Startup mount conflict accepted")
    with tempfile.TemporaryDirectory(prefix="bloodyShell-storage-helper-") as directory:
        base = Path(directory)
        for failure in ("", "verify", "mount", "missing", "external"):
            transaction(base / (failure or "success"), failure)
    print("Storage helper transactions passed without accessing system mount configuration.")


if __name__ == "__main__":
    main()
