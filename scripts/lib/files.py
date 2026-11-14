"""Atomic file writes and private temporary storage. No persistent tracking."""

import os
from contextlib import contextmanager
from pathlib import Path
import shutil
import stat
import tempfile


@contextmanager
def _atomic_output(path, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix="." + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            yield stream
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def atomic_write(path, data, mode=0o644):
    if path.is_file() and not path.is_symlink() and path.stat().st_size == len(data):
        if stat.S_IMODE(path.stat().st_mode) == mode and path.read_bytes() == data:
            return False
    with _atomic_output(path, mode) as stream:
        stream.write(data)
    return True


def same_contents(left, right):
    if left.stat().st_size != right.stat().st_size:
        return False
    with left.open("rb") as source, right.open("rb") as destination:
        while True:
            chunk = source.read(65536)
            if chunk != destination.read(65536):
                return False
            if not chunk:
                return True


def atomic_copy(source, destination, mode=0o644):
    if destination.is_file() and not destination.is_symlink():
        if stat.S_IMODE(destination.stat().st_mode) == mode and same_contents(source, destination):
            return False
    with source.open("rb") as input_file, _atomic_output(destination, mode) as output:
        shutil.copyfileobj(input_file, output)
    return True


def read_file(path):
    if not path.exists():
        return None, 0o644
    if not path.is_file():
        raise RuntimeError("Expected a regular file: " + str(path))
    return path.read_bytes(), stat.S_IMODE(path.stat().st_mode)


def safe_path(path):
    return path.is_absolute() and all(not item.is_symlink() for item in (path, *path.parents))


def private_runtime():
    base = Path(os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir())
    directory = base / ("bloodyShell" if os.environ.get("XDG_RUNTIME_DIR") else "bloodyShell-" + str(os.getuid()))
    if directory.is_symlink():
        raise ValueError("Invalid runtime directory")
    directory.mkdir(mode=0o700, exist_ok=True)
    if directory.stat().st_uid != os.getuid() or not directory.is_dir():
        raise ValueError("Invalid runtime directory")
    directory.chmod(0o700)
    return directory
