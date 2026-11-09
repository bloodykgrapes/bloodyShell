.pragma library

var basis = [];
for (let i = 0; i <= 72; i++)
{
    const angle = i / 72 * Math.PI * 2;
    basis.push({ x: Math.cos(angle), y: Math.sin(angle),
        sin5: Math.sin(5 * angle), cos5: Math.cos(5 * angle),
        sin3: Math.sin(3 * angle), cos3: Math.cos(3 * angle) });
}

function points(center, radius, amplitude, phase)
{
    const sin2 = Math.sin(phase * 2), cos2 = Math.cos(phase * 2);
    const sin13 = Math.sin(phase * 1.3), cos13 = Math.cos(phase * 1.3);
    const out = [];
    for (let i = 0; i < basis.length; i++)
    {
        const point = basis[i];
        const wave = 0.6 * (point.sin5 * cos2 + point.cos5 * sin2)
                   + 0.4 * (point.sin3 * cos13 - point.cos3 * sin13);
        const r = radius + amplitude * wave;
        out.push(Qt.point(center + r * point.x, center + r * point.y));
    }
    return out;
}

function waveBasis(width, length)
{
    const result = [];
    for (let i = 0; i <= 20; i++)
    {
        const x = i / 20 * width, angle = x / length * Math.PI * 2;
        result.push({ x: x, sine: Math.sin(angle), cosine: Math.cos(angle) });
    }
    return result;
}

function wave(basis, height, surface, amplitude, phase)
{
    const sine = Math.sin(phase), cosine = Math.cos(phase);
    const result = basis.map(point => Qt.point(point.x, surface + amplitude * (point.sine * cosine + point.cosine * sine)));
    result.push(Qt.point(basis[basis.length - 1].x, height + 2), Qt.point(0, height + 2));
    return result;
}
