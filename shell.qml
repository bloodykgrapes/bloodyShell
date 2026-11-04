import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

import "modules/altTab"
import "modules/bar"
import "modules/components"
import "modules/core"
import "modules/desktop"
import "modules/dock"
import "modules/osd"
import "modules/overlay/helper"
import "modules/overlay/launcher"
import "modules/overlay/polkit"
import "modules/overlay/power"
import "modules/overlay/settings"
import "modules/overlay/wallpapers"
import "modules/services"

ShellRoot
{
    id: shell

    function screensFor(wanted)
    {
        const all = Quickshell.screens, out = [];
        for (let i = 0; i < all.length; i++) if (wanted.length === 0 || wanted.indexOf(all[i].name) >= 0) out.push(all[i]);
        if (out.length === 0) for (let i = 0; i < all.length; i++) out.push(all[i]);
        return out;
    }
    readonly property var screensBar:  screensFor(Config.barScreens)
    readonly property var screensDock: screensFor(Config.dockScreens)

    Component.onCompleted:
    {
        void ServiceDisplay.nightLightMode;
        void ServiceUpdate.version;
        void ServiceLock.locked;
        void ServiceIdle.objectName;
        void ServiceGreeter.appearance;
        void ServiceCompositor.accent;
    }

    Variants { model: Config.initialized ? Quickshell.screens : []; Desktop { } }
    Variants { model: Config.initialized && Config.osdEnabled  ? Quickshell.screens : []; OSD  { } }
    Variants { model: Config.initialized && Config.barEnabled  ? shell.screensBar   : []; Bar  { } }
    Variants { model: Config.initialized && Config.dockEnabled ? shell.screensDock  : []; Dock { } }

    HelperStartup { }
    AltTab { }

    PolkitAgent { id: polkit }
    LazyLoader { active: polkit.isActive; Polkit { agent: polkit } }

    Loader { active: OverlayState.helperMounted;     source: "modules/overlay/helper/Helper.qml"         }
    Loader { active: OverlayState.launcherMounted;   source: "modules/overlay/launcher/Launcher.qml"     }
    Loader { active: OverlayState.settingsMounted;   source: "modules/overlay/settings/Settings.qml"     }
    Loader { active: OverlayState.powerMounted;      source: "modules/overlay/power/Power.qml"           }
    Loader { active: OverlayState.wallpapersMounted; source: "modules/overlay/wallpapers/Wallpapers.qml" }

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
