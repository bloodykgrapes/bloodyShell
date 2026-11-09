import QtQuick

import "../../../common"

RevealSection
{
    required property Item host
    shown: host.opened
    spacing: 0
}
