pragma Singleton

import QtQuick
import Quickshell

Singleton
{
    id: surfaceState

    property var dockCut: ({})
    function setDockCut(screenName, rect)
    {
        const all = Object.assign({}, dockCut);
        if (rect) all[screenName] = rect; else delete all[screenName];
        dockCut = all;
    }
}
