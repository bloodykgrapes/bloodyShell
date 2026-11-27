import QtQuick

import "../../../../common"
import "../../../../core"

Column
{
    id: rowGroup

    property string title: ""
    property string summary: ""
    property string description: ""

    default property alias content: rows.data

    width: parent ? parent.width : 400
    spacing: 12

    SettingsSectionHeading
    {
        width: parent.width
        title: rowGroup.title
        summary: rowGroup.summary
    }

    ShellText
    {
        width: parent.width
        visible: rowGroup.description !== ""
        label: rowGroup.description
        size: 12
        color: Theme.text3
        wrapMode: Text.Wrap
    }

    Column { id: rows; width: parent.width; spacing: 1 }
}
