.pragma library

function sync(model, items, key) {
    for (let i = model.count - 1; i >= 0; i--) {
        const k = model.get(i)[key];
        if (!items.some(it => it[key] === k)) model.remove(i);
    }
    for (let t = 0; t < items.length; t++) {
        const it = items[t];
        let found = -1;
        for (let i = t; i < model.count; i++)
            if (model.get(i)[key] === it[key]) { found = i; break }
        if (found < 0) { model.insert(t, it); continue; }
        if (found !== t) model.move(found, t, 1);
        const row = model.get(t);
        for (const k in it) if (row[k] !== it[k]) model.setProperty(t, k, it[k]);
    }
}
