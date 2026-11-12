.pragma library

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
