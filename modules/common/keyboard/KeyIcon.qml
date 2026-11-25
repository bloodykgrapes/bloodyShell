import QtQuick
import QtQuick.Shapes

Item
{
    id: icon
    property string name: ""
    property color color: "white"
    readonly property string path: ({
        backspace: "M9 5H21V19H9L2 12Z M12 9L18 15 M18 9L12 15",
        tab: "M3 12H17 M12 7L17 12L12 17 M21 5V19",
        caps: "M7 14V10H3L12 2L21 10H17V14Z M7 19H17V22H7Z",
        shift: "M8 21V13H3L12 4L21 13H16V21Z",
        enter: "M20 5V11Q20 14 17 14H4 M9 9L4 14L9 19",
        left: "M20 12H4 M10 6L4 12L10 18",
        right: "M4 12H20 M14 6L20 12L14 18",
        space: "M4 9V15H20V9",
        close: "M6 9L12 15L18 9"
    })[name] || ""

    implicitWidth: 22
    implicitHeight: 22
    Shape
    {
        width: 24
        height: 24
        anchors.centerIn: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { origin.x: 12; origin.y: 12; xScale: icon.width / 24; yScale: icon.height / 24 }
        ShapePath
        {
            strokeColor: icon.color
            strokeWidth: 1.7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.path }
        }
    }
}
