.pragma library

function update(current, changes, replace) {
    let next = current;
    const seen = replace ? Object.create(null) : null;
    for (const [id, layout] of changes) {
        const size = layout?.tile_size;
        const valid = size?.length === 2 && Number.isFinite(size[0]) && Number.isFinite(size[1]) && size[0] > 0 && size[1] > 0;
        const old = next[id];
        if (seen) {
            if (valid) seen[id] = true;
            else delete seen[id];
        }
        if (valid && old && old.width === size[0] && old.height === size[1]) continue;
        if (!valid && !old) continue;
        if (next === current) next = Object.assign({}, current);
        if (valid) next[id] = {width: size[0], height: size[1]};
        else delete next[id];
    }
    if (seen) {
        for (const id of Object.keys(current)) {
            if (seen[id]) continue;
            if (next === current) next = Object.assign({}, current);
            delete next[id];
        }
    }
    return next;
}

function fullscreen(outputs, workspaces, windows, layouts, overview, cache) {
    const next = [];
    if (!overview) {
        const active = new Map();
        for (let i = 0; i < workspaces.count; i++) {
            const workspace = workspaces.get(i);
            if (workspace.activated) active.set(workspace.output, workspace);
        }
        for (const output of outputs) {
            const workspace = active.get(output.name);
            if (!workspace) continue;
            const window = windows.find(window => window.id === workspace.activeWindowId && window.workspace_id === workspace.wsId);
            const tile = window ? layouts[window.id] : null;
            // Positions are optional in niri IPC. Tile size includes the
            // fullscreen backdrop of fixed-size and letterboxed windows.
            if (tile && Math.abs(tile.width - output.width) <= 2 && Math.abs(tile.height - output.height) <= 2)
                next.push(output.name);
        }
    }
    if (cache.outputs.length !== next.length || next.some((name, index) => name !== cache.outputs[index])) cache.outputs = next;
    return cache.outputs;
}
