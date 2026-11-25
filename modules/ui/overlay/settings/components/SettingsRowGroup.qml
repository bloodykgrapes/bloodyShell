import QtQuick

Column
{
    id: rowGroup

    property string title: ""

    default property alias content: rows.data

    width: parent ? parent.width : 400
    spacing: 12

    SettingsSectionHeading
    {
        width: parent.width
        title: rowGroup.title
    }

    Column { id: rows; width: parent.width; spacing: 1 }
}
