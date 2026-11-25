.pragma library

// Keep a short straight edge between the frame join and the outer corner.
const tangent = 4;

function pixelBounds(rect)
{
    const x = Math.ceil(rect.x), y = Math.ceil(rect.y);
    return Qt.rect(x, y, Math.max(0, Math.floor(rect.x + rect.width) - x),
        Math.max(0, Math.floor(rect.y + rect.height) - y));
}

function smooth(value)
{
    const t = Math.max(0, Math.min(1, value));
    return t * t * (3 - 2 * t);
}

function bodyShape(area, width, height, inset, radius, smoothing, pixelAligned)
{
    const bounds = pixelAligned ? pixelBounds(area) : area;
    const joins = Math.min(smoothing, bounds.width, bounds.height);
    let cap = Math.max(0, Math.min(radius, bounds.width / 2, bounds.height / 2));
    const noJoins = Qt.vector4d(0, 0, 0, 0);
    if (inset <= 0 || joins <= 0)
    {
        const corner = pixelAligned ? Math.ceil(cap) : cap;
        return { bounds, corners: Qt.vector4d(corner, corner, corner, corner), fillets: noJoins };
    }

    // Qt sends rectangles to the shader as floats. Round the far faces the same way at contact.
    const endX = Math.fround(bounds.x + bounds.width), endY = Math.fround(bounds.y + bounds.height);
    const farX = Math.fround(width - inset), farY = Math.fround(height - inset);
    const left = bounds.x - inset, right = farX - endX;
    const top = bounds.y - inset, bottom = farY - endY;
    const depths = [endY - inset, farY - bounds.y, endX - inset, farX - bounds.x];
    const contacts = [top, bottom, left, right].map((gap, index) => gap <= 0 && depths[index] > 0);
    for (let edge = 0; edge < contacts.length; edge++)
        if (contacts[edge]) cap = Math.min(cap, Math.max(0, (depths[edge] - tangent) / 2));

    const edgeBlend = pixelAligned ? 1 : smooth(inset);
    function corner(horizontal, vertical)
    {
        const rounded = smooth(Math.min(horizontal, vertical) / Math.max(1, joins / 2));
        return pixelAligned ? Math.ceil(cap * rounded) : cap * (1 - edgeBlend + rounded * edgeBlend);
    }
    const fillets = depths.map((depth, edge) => contacts[edge] ? Math.max(0, Math.floor(Math.min(joins, depth - cap - tangent))) : 0);
    return {
        bounds,
        // The mask and shader use the same order for corners and edges.
        corners: Qt.vector4d(corner(left, top), corner(right, top), corner(left, bottom), corner(right, bottom)),
        fillets: Qt.vector4d(fillets[0], fillets[1], fillets[2], fillets[3])
    };
}
