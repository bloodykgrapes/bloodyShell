"""Native plugin builds and audio helpers. Dispatched by backend.py."""

from pathlib import Path
import fcntl
import hashlib
import json
import os
import platform
import runpy
import shlex
import shutil
import socket
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
    files = runpy.run_path(str(Path(__file__).with_name("files.py")))
    with tempfile.TemporaryDirectory(prefix="visualizer-", dir=files["private_runtime"]()) as temporary:
        config = Path(temporary) / "cava.conf"
        # Keep headroom before Cava's output limiter; ServiceMedia controls the display gain.
        config.write_text(f"[general]\nbars = {bars}\nframerate = 30\nsleep_timer = 1\nautosens = 0\nsensitivity = 1\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 65535\nbar_delimiter = 59\nframe_delimiter = 10\n[smoothing]\nnoise_reduction = 70\n")
        backend = runpy.run_path(str(Path(__file__).with_name("backend.py")))
        return backend["supervise"](["cava", "-p", str(config)])


def effects_preset_name(name):
    return bool(name and len(name.encode("utf-8")) <= 100 and name not in (".", "..")
                and not any(char in "/\\" or ord(char) < 32 or ord(char) == 127 for char in name))


def effects_presets():
    data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "easyeffects"
    return {pipeline: sorted((path.stem for path in (data / pipeline).glob("*.json")
                              if path.is_file() and effects_preset_name(path.stem)), key=str.casefold)
            for pipeline in ("output", "input")}


def effects_query(connection, message, newline=True):
    connection.sendall((message + "\n").encode("utf-8"))
    reply = bytearray()
    while len(reply) < 4096:
        chunk = connection.recv(1 if not newline else 512)
        if not chunk:
            raise RuntimeError("EasyEffects closed the connection. Try again.")
        reply.extend(chunk)
        if not newline or reply.endswith(b"\n"):
            return reply.decode("utf-8").rstrip("\n")
    raise RuntimeError("Invalid reply from EasyEffects.")


def effects_snapshot(connection, state):
    bypass = effects_query(connection, "get_global_bypass", newline=False)
    if bypass not in ("1", "2"):
        raise RuntimeError("Could not read EasyEffects state. Update EasyEffects and try again.")
    state.update(running=True, bypass=bypass == "1", current={
        pipeline: effects_query(connection, "get_last_loaded_preset:" + pipeline) for pipeline in ("output", "input")})
    return state


def easyeffects_main():
    args = sys.argv[1:]
    if not (args == ["status"] or len(args) == 2 and args[0] == "effects" and args[1] in ("true", "false")
            or len(args) == 3 and args[0] == "preset" and args[1] in ("output", "input") and effects_preset_name(args[2])):
        raise ValueError("Usage: easyeffects status | effects true/false | preset output/input <name>")
    command = shutil.which("easyeffects")
    state = dict(installed=bool(command), running=False, command=[command] if command else [], bypass=None,
                 presets=effects_presets() if command else {"output": [], "input": []}, current={"output": "", "input": ""})
    if not command:
        if args != ["status"]:
            raise RuntimeError("EasyEffects is not installed.")
        print(json.dumps(state))
        return
    if args[0] == "preset" and args[2] not in state["presets"][args[1]]:
        raise ValueError("This EasyEffects preset no longer exists.")
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR") or "/run/user/" + str(os.getuid()))
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(0.8)
            try:
                connection.connect(str(runtime / "EasyEffectsServer"))
            except (FileNotFoundError, ConnectionRefusedError):
                if args != ["status"]:
                    raise RuntimeError("Start EasyEffects before changing effects or presets.")
            else:
                state["running"] = True
                if args[0] == "effects":
                    connection.sendall(("global_bypass:" + ("0" if args[1] == "true" else "1") + "\n").encode())
                elif args[0] == "preset":
                    connection.sendall(("load_preset:" + args[1] + ":" + args[2] + "\n").encode("utf-8"))
                effects_snapshot(connection, state)
                if args[0] == "effects" and state["bypass"] != (args[1] == "false"):
                    raise RuntimeError("EasyEffects did not apply the effects change. Try again.")
                if args[0] == "preset" and state["current"][args[1]] != args[2]:
                    raise RuntimeError("EasyEffects could not load the preset. Check it in EasyEffects.")
    except (OSError, RuntimeError, UnicodeError) as failure:
        message = "EasyEffects did not respond. Update EasyEffects and try again." if isinstance(failure, TimeoutError) else str(failure)
        if args != ["status"]:
            raise RuntimeError(message) from failure
        state["error"] = message
    print(json.dumps(state))
