import "../core"

Ease
{
    elastic: Config.animationsFluid
    duration: Config.animationsFluid ? 420 : 160
    curve: Config.animationsFluid ? [0.18, 1.5, 0.35, 1.0, 1.0, 1.0] : Theme.easingEmphasized
}
