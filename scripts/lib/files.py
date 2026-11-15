"""Atomic file operations, validated archives and owned worker processes."""

import os
from contextlib import contextmanager
from pathlib import Path, PurePosixPath
import shutil
import signal
import stat
import subprocess
import tarfile
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


def remove_path(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def copy_path(source, destination):
    if source.is_symlink():
        destination.symlink_to(os.readlink(source))
    elif source.is_dir():
        shutil.copytree(source, destination, symlinks=True)
    else:
        shutil.copy2(source, destination)


@contextmanager
def operation_signals(*signals):
    def interrupt(signum, frame):
        raise SystemExit(128 + signum)
    previous = {sig: signal.signal(sig, interrupt) for sig in signals or (signal.SIGTERM, signal.SIGINT, signal.SIGHUP)}
    try:
        yield
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def stop_process(child, timeout=2):
    if child.poll() is not None:
        return
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        child.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        pass
    finally:
        # A worker may exit before one of its children. The whole group belongs
        # to this operation, including children that ignore SIGTERM.
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        child.wait()


def run(command, *, check=False, capture_output=False, timeout=None, **options):
    """Run a noninteractive worker and stop its process group on cancellation."""
    if capture_output:
        options.update(stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    options.setdefault("stdin", subprocess.DEVNULL)
    child = subprocess.Popen(command, start_new_session=True, **options)
    try:
        stdout, stderr = child.communicate(timeout=timeout)
        result = subprocess.CompletedProcess(command, child.returncode, stdout, stderr)
        if check:
            result.check_returncode()
        return result
    finally:
        stop_process(child)
        for stream in (child.stdout, child.stderr):
            if stream is not None:
                stream.close()


def extract_archive(archive, target, prefix=None, allow_links=False):
    if target.is_symlink() or not target.is_dir() or any(target.iterdir()):
        raise ValueError("Archive extraction needs an empty directory")
    root, total, seen, links = None, 0, set(), []
    with tarfile.open(archive, "r:gz") as package:
        for member in package:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts or not path.parts:
                raise ValueError("Unsafe archive path")
            root = root or path.parts[0]
            if path.parts[0] != root:
                raise ValueError("Archive must contain one root directory")
            if len(path.parts) == 1:
                if not member.isdir():
                    raise ValueError("Invalid archive root")
                continue
            relative = Path(*path.parts[1:])
            if relative in seen:
                raise ValueError("Duplicate path in archive")
            seen.add(relative)
            if len(seen) > 100000:
                raise ValueError("Archive contains too many files")
            if prefix is not None and not relative.is_relative_to(prefix):
                continue
            destination = target / relative
            if member.isdir():
                destination.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                total += member.size
                if total > 512 * 1024 * 1024:
                    raise ValueError("Archive is too large")
                destination.parent.mkdir(parents=True, exist_ok=True)
                with package.extractfile(member) as source, destination.open("xb") as output:
                    shutil.copyfileobj(source, output)
                destination.chmod(member.mode & 0o755)
            elif member.issym() and allow_links:
                link = PurePosixPath(member.linkname)
                if link.is_absolute() or not (destination.parent / str(link)).resolve().is_relative_to(target.resolve()):
                    raise ValueError("Link escapes archive")
                links.append((destination, str(link)))
            else:
                raise ValueError("Archive contains a link or special file")
        for destination, link in links:
            if not destination.parent.resolve().is_relative_to(target.resolve()):
                raise ValueError("Link escapes archive")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.symlink_to(link)
        for destination, _ in links:
            if not destination.resolve(strict=True).is_relative_to(target.resolve()):
                raise ValueError("Link escapes archive")


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
