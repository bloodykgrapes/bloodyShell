pragma Singleton

import QtQuick
import Quickshell

import "../services"
import "../src/Clients.js" as Clients

Singleton
{
    readonly property int mode: Config.shellSurface === Enums.SurfaceBlur && !ServiceCompositor.supports("backgroundBlur")
        ? Enums.SurfaceBackdrop : Config.shellSurface
    readonly property bool blur: mode === Enums.SurfaceBlur
    readonly property bool backdrop: mode === Enums.SurfaceBackdrop
    readonly property real blurStrength: Math.max(0, Math.min(1, Number(Config.surfaceBlurStrength) / 100))
    readonly property real blurGrain: Math.max(0, Math.min(1, Number(Config.surfaceBlurGrain) / 100))
    readonly property url wallpaper: backdrop && ServiceAppearance.wallpaperImage
        ? ServiceAppearance.fileUrl(ServiceAppearance.wallpaperImage) : ""
    readonly property real preferredWallpaperStrength: Theme.light ? 0.16 : 0.26
    property var blurClients: []

    function fill(base, frosted)
    {
        if (!frosted) return base;
        const preferred = 0.62 - blurStrength * 0.28;
        return Qt.rgba(base.r, base.g, base.b, base.a * readableOpacity(base, preferred));
    }

    function wallpaperStrength(base)
    {
        const preferred = preferredWallpaperStrength * (0.35 + blurStrength * 0.9);
        return 1 - readableOpacity(base, 1 - preferred);
    }

    function readableOpacity(base, preferred)
    {
        // Check muted labels against the worst background for the active theme.
        const ink = Theme.luminance(Theme.text3) + 0.05;
        const extreme = Theme.light ? 0 : 1;
        const contrast = 4.6;
        const limit = Theme.light ? ink * contrast : ink / contrast;
        let low = preferred, high = 1;
        for (let step = 0; step < 8; step++)
        {
            const opacity = (low + high) / 2;
            const behind = extreme * (1 - opacity);
            const luminance = Theme.luminance(Qt.rgba(
                base.r * opacity + behind, base.g * opacity + behind, base.b * opacity + behind, 1)) + 0.05;
            if (Theme.light ? luminance >= limit : luminance <= limit) high = opacity;
            else low = opacity;
        }
        return high;
    }

    function setBlurClient(client, active)
    {
        blurClients = Clients.update(blurClients, client, active);
    }

    function regionsFor(window)
    {
        if (!window) return [];
        return blurClients.filter(client => client.surfaceWindow === window).map(client => client.blurMask);
    }

    function localCanvasFor(item)
    {
        for (let node = item.parent; node; node = node.parent)
            if (node.localMaterialCanvas === true) return node;
        return null;
    }

    function boundsIn(item, target)
    {
        // Mapping coordinates alone doesn't track movement of the item's ancestors.
        for (let node = item; node && node !== target; node = node.parent)
        {
            void node.x; void node.y; void node.width; void node.height; void node.scale;
        }
        return item.mapToItem(target, 0, 0, item.width, item.height);
    }
}
