import "../core"

Button
{
    property bool checked: false

    radius: primary ? Theme.radiusLarge : height / 2
    color: primary || checked ? Theme.colorSelection : Theme.colorField
    textColor: danger ? Theme.colorCritical : Theme.text1
    hoverColor: danger ? Theme.criticalAlpha(visualFocus ? 0.22 : 0.12) : visualFocus ? Theme.colorHoverStrong : Theme.colorHover
}
