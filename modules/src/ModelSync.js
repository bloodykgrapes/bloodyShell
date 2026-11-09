.pragma library

function sync(model, items, key)
{
    if (items.length === 0)
    {
        const changed = model.count > 0;
        if (changed) model.clear();
        return changed;
    }

    const keyOf = typeof key === "function" ? key : item => item[key];
    let changed = false;
    const wanted = new Set(items.map(keyOf));
    const order = [];
    for (let i = model.count - 1; i >= 0; i--)
    {
        const value = keyOf(model.get(i));
        if (!wanted.has(value)) { model.remove(i); changed = true; }
        else order.push(value);
    }
    order.reverse();

    for (let target = 0; target < items.length; target++)
    {
        const item = items[target];
        const found = order.indexOf(keyOf(item), target);
        if (found < 0)
        {
            model.insert(target, item);
            changed = true;
            order.splice(target, 0, keyOf(item));
            continue;
        }
        if (found !== target)
        {
            model.move(found, target, 1);
            changed = true;
            order.splice(target, 0, order.splice(found, 1)[0]);
        }
        const row = model.get(target);
        for (const role in item)
        {
            if (row[role] === item[role]) continue;
            model.setProperty(target, role, item[role]);
            changed = true;
        }
    }
    return changed;
}
