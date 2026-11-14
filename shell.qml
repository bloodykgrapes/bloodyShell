//@ pragma ShellId bloodyShell

import QtQuick
import Quickshell
import Quickshell.Io

import "modules/core"
import "modules/services"
import "modules/ui/desktop"
import "modules/ui/layout"
import "modules/ui/overlay"
import "modules/ui/overlay/helper"
import "modules/ui/keyboard"

ShellRoot
{
    id: shell

    Component.onCompleted:
    {
        void ServiceDisplay.nightLightMode;
        void ServiceUpdate.version;
        void ServiceLock.locked;
        void ServiceIdle.objectName;
        void ServicePowerProfiles.current;
        void ServiceGreeter.appearance;
        void ServiceCompositor.windowList;
    }

    Variants { model: Config.initialized ? Quickshell.screens : []; Desktop { } }
    Variants { model: Config.initialized ? Quickshell.screens : []; Layout { } }

    Overlay { }
    HelperStartup { }
    VirtualKeyboard { }

    IpcHandler
    {
        target: "keyboard"
        function show(): void { ServiceVirtualKeyboard.show(); }
        function hide(): void { ServiceVirtualKeyboard.hide(); }
        function toggle(): void { ServiceVirtualKeyboard.toggle(); }
    }

    Variants
    {
        model: Registry.windows

        Scope
        {
            id: handler
            required property string modelData

            IpcHandler
            {
                target: handler.modelData

                function show():   void { OverlayState.show(target)   }
                function hide():   void { OverlayState.hide(target)   }
                function toggle(): void { OverlayState.toggle(target) }
            }
        }
    }

    IpcHandler
    {
        target: "lock"

        function lock():     void { ServiceLock.lock() }
        function isLocked(): bool { return ServiceLock.locked }
    }
}
