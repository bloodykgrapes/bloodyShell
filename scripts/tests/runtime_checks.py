#!/usr/bin/env python3

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checks():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-runtime-") as temporary:
        base = Path(temporary)
        shutil.copytree(ROOT / "modules/src", base / "src", ignore=shutil.ignore_patterns("keyboard"))
        (base / "runtime").mkdir(mode=0o700)
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "src/Clients.js" as Clients
import "src/ModelSync.js" as ModelSync
import "src/Visualizer.js" as Visualizer

ShellRoot
{
    id: tests
    property int delegates: 0
    ListModel { id: model }
    QtObject { id: first }
    QtObject { id: second }
    Item
    {
        Repeater
        {
            id: rows
            model: model
            Item
            {
                required property int key
                required property string text
                Component.onCompleted: tests.delegates++
            }
        }
    }
    function check(ok, message) { if (!ok) throw new Error(message); }
    Component.onCompleted: Qt.callLater(() =>
    {
        try
        {
            let clients = [];
            check(Clients.update(clients, first, false) === clients, "Removing an absent client allocated a new array");
            clients = Clients.update(clients, first, true);
            check(Clients.update(clients, first, true) === clients, "Duplicate client registration invalidated subscribers");
            clients = Clients.update(clients, second, true);
            clients = Clients.update(clients, first, false);
            check(clients.length === 1 && clients[0] === second, "Removing one consumer stopped another consumer");
            check(Clients.update(clients, second, false).length === 0, "Last consumer was retained");

            ModelSync.sync(model, [{key:1,text:"one"},{key:2,text:"two"}], "key");
            const original = rows.itemAt(0), other = rows.itemAt(1);
            check(!ModelSync.sync(model, [{key:1,text:"one"},{key:2,text:"two"}], "key"), "Identical model reported a change");
            check(ModelSync.sync(model, [{key:2,text:"updated"},{key:1,text:"one"}], item => item.key), "Computed identities did not reconcile");
            check(rows.itemAt(1) === original && rows.itemAt(0) === other && tests.delegates === 2, "Reordering recreated delegates");
            check(other.text === "updated", "Changed role did not reach its existing delegate");
            rows.model = null;

            let seed = 1729;
            function random() { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; }
            for (let round = 0; round < 120; round++)
            {
                const items = [];
                for (let i = 0; i < 80; i++)
                    if (random() > 0.3) items.push({key:i,text:"value-" + round + "-" + i});
                for (let i = items.length - 1; i > 0; i--)
                {
                    const j = Math.floor(random() * (i + 1));
                    [items[i], items[j]] = [items[j], items[i]];
                }
                ModelSync.sync(model, items, "key");
                check(model.count === items.length, "Reconcile retained a stale row");
                for (let i = 0; i < items.length; i++)
                    check(model.get(i).key === items[i].key && model.get(i).text === items[i].text, "Mixed insertion/removal/reordering corrupted the model");
                check(!ModelSync.sync(model, items, "key"), "A settled model still writes roles");
            }

            const items = Array.from({length:500}, (_, key) => ({key:key,text:String(key)}));
            ModelSync.sync(model, items, "key");
            let reads = 0;
            const tracked = {
                get count() { return model.count; },
                get(index) { reads++; return model.get(index); },
                insert(index, item) { model.insert(index, item); },
                remove(index) { model.remove(index); },
                move(from, to, count) { model.move(from, to, count); },
                setProperty(index, role, value) { model.setProperty(index, role, value); },
                clear() { model.clear(); }
            };
            ModelSync.sync(tracked, items.reverse(), "key");
            check(reads <= 1000 && model.get(0).key === 499, "Reordering repeated native model searches");
            ModelSync.sync(model, [], "key");
            check(model.count === 0 && !ModelSync.sync(model, [], "key"), "Empty model reset is not idempotent");

            for (const length of [48, 62])
            {
                const basis = Visualizer.waveBasis(64, length);
                for (const phase of [0, 0.1, 4, 25, -6])
                {
                    const points = Visualizer.wave(basis, 64, 24, 2.6, phase);
                    check(points.length === 23, "Liquid wave resolution changed");
                    for (let i = 0; i <= 20; i++)
                    {
                        const x = i / 20 * 64;
                        check(Math.abs(points[i].x - x) < 1e-7 && Math.abs(points[i].y - (24 + 2.6 * Math.sin(x / length * Math.PI * 2 + phase))) < 1e-7, "Cached trigonometry changed the liquid shape");
                    }
                }
            }
            console.log("RUNTIME_PASSED client ownership, delegate identity, 120 mixed model updates,", reads, "native reads for 500 reversed rows, and identical wave geometry");
        }
        catch (error) { console.error("RUNTIME_FAILED", error); }
        Qt.quit();
    })
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"))
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "RUNTIME_PASSED" in output, output
        assert not re.search(r"RUNTIME_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type", output), output


if __name__ == "__main__":
    checks()
