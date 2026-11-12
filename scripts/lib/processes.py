"""Native plugin builds and supervised visualizer processes. Dispatched by backend.py."""

from pathlib import Path
import fcntl
import hashlib
import os
import platform
import runpy
import shlex
import shutil
import subprocess
import sys
import tempfile


SOURCE = Path(__file__).resolve().parents[2] / "modules/src"
NATIVE_PLUGINS = {
    "keyboard": dict(source="keyboard", library="keyboardstate", module="Keyboard", wrapper="Monitor.qml",
                     unit="KeyboardMonitor.cpp", moc="keyboard.moc", packages=("Qt6Quick",)),
    "virtual-keyboard": dict(source="virtualKeyboard", library="virtualkeyboard", module="VirtualKeyboard", wrapper="Engine.qml",
                             unit="VirtualKeyboard.cpp", moc="virtualkeyboard.moc", packages=("Qt6Quick", "wayland-client", "xkbcommon"),
                             protocol="virtual-keyboard.xml", contents=b'import QtQuick\nimport "plugin"\nVirtualKeyboardEngine {}\n'),
}


def output(args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE).strip()


def write_changed(path, data):
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def compile_plugin(spec, source, cache, library):
    compiler = shutil.which("c++") or shutil.which("g++")
    if not compiler:
        raise RuntimeError("Native keyboard support needs a C++ compiler. Run bloodyShell install to prepare it.")
    libexec = Path(output(["pkg-config", "--variable=libexecdir", "Qt6Core"]))
    moc = next((path for path in (libexec / "moc", libexec / "libexec/moc") if path.is_file()), None)
    if not moc:
        raise RuntimeError("Qt 6 development tools are required for native keyboard support")
    flags = shlex.split(output(["pkg-config", "--cflags", "--libs", *spec["packages"]]))
    includes = [flag for flag in flags if flag.startswith(("-I", "-D"))]
    objects = []
    if "protocol" in spec:
        scanner = shutil.which("wayland-scanner")
        if not scanner:
            raise RuntimeError("The virtual keyboard needs wayland-scanner. Run bloodyShell install to prepare it.")
        protocol = str(source / spec["protocol"])
        subprocess.run([scanner, "client-header", protocol, str(cache / "virtual-keyboard-client.h")], check=True)
        subprocess.run([scanner, "private-code", protocol, str(cache / "virtual-keyboard-protocol.c")], check=True)
        subprocess.run(["cc", "-fPIC", "-c", str(cache / "virtual-keyboard-protocol.c"), "-o", str(cache / "protocol.o")], check=True)
        objects.append(str(cache / "protocol.o"))
    subprocess.run([str(moc), *includes, str(source / spec["unit"]), "-o", str(cache / spec["moc"])], check=True)
    temporary = library.with_suffix(".so.tmp")
    try:
        subprocess.run([compiler, "-std=c++17", "-shared", "-fPIC", "-O2", "-I" + str(cache),
                        str(source / spec["unit"]), *objects, "-o", str(temporary), *flags], check=True)
        temporary.replace(library)
    finally:
        temporary.unlink(missing_ok=True)


def native_plugin(name, destination=None):
    spec = NATIVE_PLUGINS[name]
    source = SOURCE / spec["source"]
    version = output(["pkg-config", "--modversion", *spec["packages"]])
    inputs = Path(__file__).read_bytes() + b"".join(path.read_bytes() for path in sorted(source.iterdir()) if path.is_file())
    digest = hashlib.sha256(inputs + version.encode() + platform.machine().encode()).hexdigest()[:16]
    cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "bloodyShell" / name / digest
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (cache / "build.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        plugin = cache / "plugin"
        plugin.mkdir(exist_ok=True)
        library = plugin / ("lib" + spec["library"] + ".so")
        if not library.exists():
            compile_plugin(spec, source, cache, library)
        # Qt protects imported modules. A rebuilt plugin needs its own namespace
        # so a running shell can load it after a QML configuration reload.
        module = "BloodyShell." + spec["module"] + ".Build" + digest
        write_changed(plugin / "qmldir", f"module {module}\nplugin {spec['library']}\n".encode())
        contents = spec["contents"] if "contents" in spec else (source / spec["wrapper"]).read_bytes()
        write_changed(cache / spec["wrapper"], contents)
        if destination is not None:
            destination.mkdir(parents=True, exist_ok=True)
            shutil.copy2(cache / spec["wrapper"], destination / spec["wrapper"])
            shutil.copytree(plugin, destination / "plugin", dirs_exist_ok=True)
    return (cache / spec["wrapper"]).as_uri()


def keyboard_main():
    print(native_plugin("keyboard"))


def virtual_keyboard_main():
    if len(sys.argv) > 2:
        raise ValueError("Usage: build-virtual-keyboard [destination]")
    print(native_plugin("virtual-keyboard", Path(sys.argv[1]) if len(sys.argv) > 1 else None))


def visualizer_main():
    """Supervise cava with a private, automatically removed configuration."""
    bars = int(sys.argv[1])
    if not 1 <= bars <= 256:
        raise ValueError("Invalid visualizer bar count")
    ownership = runpy.run_path(str(Path(__file__).with_name("ownership.py")))
    with tempfile.TemporaryDirectory(prefix="visualizer-", dir=ownership["private_runtime"]()) as temporary:
        config = Path(temporary) / "cava.conf"
        config.write_text(f"[general]\nbars = {bars}\nframerate = 30\nsleep_timer = 1\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 1000\nbar_delimiter = 59\nframe_delimiter = 10\n[smoothing]\nnoise_reduction = 70\n")
        backend = runpy.run_path(str(Path(__file__).with_name("backend.py")))
        return backend["supervise"](["cava", "-p", str(config)])
