import QtQuick
import QtQuick.Effects

MultiEffect
{
    property bool soft: false

    shadowEnabled: true
    shadowColor: "#000000"
    shadowOpacity: soft ? 0.45 : 0.7
    shadowBlur: soft ? 0.3 : 0.5
    shadowVerticalOffset: soft ? 1 : 2
    shadowHorizontalOffset: 0
}
