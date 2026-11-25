.pragma library

const fluidOpenDuration = 320
const fluidCloseDuration = 210
const fluidOpenCurve = [0.22, 0.0, 0.24, 1.0, 1.0, 1.0]
const fluidCloseCurve = [0.38, 0.0, 0.62, 1.0, 1.0, 1.0]
const wallpapersOpenDuration = 360
const wallpapersCurve = [0.28, 0.10, 0.68, 0.95, 1.0, 1.0]

function openDuration(name)
{
    return name === "wallpapers" ? wallpapersOpenDuration : fluidOpenDuration;
}

function openCurve(name)
{
    return name === "wallpapers" ? wallpapersCurve : fluidOpenCurve;
}

function unit(value)
{
    return Math.max(0, Math.min(1, value));
}

function smooth(value)
{
    const progress = unit(value);
    return progress * progress * (3 - 2 * progress);
}

function phase(reveal, start, end)
{
    return smooth((reveal - start) / (end - start));
}

function extent(reveal, width, height)
{
    return Math.max(width, height) * unit(reveal);
}

function contentOpacity(reveal)
{
    return phase(reveal, 0.50, 0.94);
}

function panelOpacity(reveal, fluid)
{
    return fluid ? (reveal > 0 ? 1 : 0) : reveal;
}

function scrimOpacity(reveal, fluid)
{
    return 0.6 * (fluid ? smooth(reveal) : reveal);
}
