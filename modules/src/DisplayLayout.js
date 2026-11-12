.pragma library

function fit(screens, width, height, padding)
{
    if (screens.length === 0) return { s: 1, ox: 0, oy: 0 };

    let left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity;
    for (const screen of screens)
    {
        left = Math.min(left, screen.x);
        top = Math.min(top, screen.y);
        right = Math.max(right, screen.x + screen.w);
        bottom = Math.max(bottom, screen.y + screen.h);
    }

    const scale = Math.max(0.001, Math.min(
        Math.max(1, width - padding * 2) / ((right - left) * 1.6),
        Math.max(1, height - padding * 2) / ((bottom - top) * 1.6)
    ));
    return { s: scale, ox: width / 2 - (left + right) / 2 * scale, oy: height / 2 - (top + bottom) / 2 * scale };
}

function align(value, targets, threshold)
{
    let nearest = value, distance = threshold;
    for (const target of targets)
    {
        const delta = Math.abs(value - target);
        if (delta < distance) { nearest = target; distance = delta; }
    }
    return nearest;
}

function overlaps(position, width, height, screen)
{
    return position.x < screen.x + screen.w && position.x + width > screen.x
        && position.y < screen.y + screen.h && position.y + height > screen.y;
}

function snap(screens, moving, threshold)
{
    const { name, x, y, w, h } = moving;
    const others = screens.filter(screen => screen.name !== name);
    if (others.length === 0) return { x: Math.round(x), y: Math.round(y) };

    let best = null, distance = Infinity;
    const consider = (px, py) =>
    {
        const position = { x: Math.round(px), y: Math.round(py) };
        if (others.some(screen => overlaps(position, w, h, screen))) return false;
        const delta = (position.x - x) ** 2 + (position.y - y) ** 2;
        if (delta < distance) { distance = delta; best = position; }
        return true;
    };

    // Obstacle edges provide free slots in layouts with three or more displays.
    const verticalEdges = [], horizontalEdges = [];
    for (const screen of others)
    {
        verticalEdges.push(screen.y - h, screen.y + screen.h);
        horizontalEdges.push(screen.x - w, screen.x + screen.w);
    }

    for (const screen of others)
    {
        const ys = [screen.y, screen.y + screen.h - h, screen.y + (screen.h - h) / 2];
        const xs = [screen.x, screen.x + screen.w - w, screen.x + (screen.w - w) / 2];
        for (const px of [screen.x - w, screen.x + screen.w])
        {
            for (const value of [y, ...ys, ...verticalEdges])
            {
                const py = Math.max(screen.y - h + 1, Math.min(screen.y + screen.h - 1, value));
                if (!consider(px, align(py, ys, threshold))) consider(px, py);
            }
        }
        for (const py of [screen.y - h, screen.y + screen.h])
        {
            for (const value of [x, ...xs, ...horizontalEdges])
            {
                const px = Math.max(screen.x - w + 1, Math.min(screen.x + screen.w - 1, value));
                if (!consider(align(px, xs, threshold), py)) consider(px, py);
            }
        }
    }
    return best;
}
