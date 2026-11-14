pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton
{
    id: config

    readonly property bool animationsEnabled: themeAnimations >= Enums.AnimationsStandard
    readonly property bool animationsFluid:   themeAnimations >= Enums.AnimationsFluid

    property real scrollSpeed: 2.5
    property bool debug: false
    property bool helperSeen: false
    property bool virtualKeyboardEnabled: false
    property string applicationBrowser: ""
    property string applicationFileManager: ""
    property string applicationTerminal: ""

    property bool updateBeta: false
    property bool updateAuto: false
    property int  updateCheck: 4

    property int  themeStyle: 1
    property int  themeAnimations: 1
    property bool themeAccent: false

    property int frameThickness: 8

    property string wallpaperCurrent: ""
    property string wallpaperDirectory: Paths.home + "/Pictures/Wallpapers"
    property string wallpaperTransition: "grow"

    property int equalizerStyle: 0
    property bool desktopEqualizer: true
    property real desktopEqualizerOpacity: 1
    property int desktopBlur: 0

    property bool barEnabled: true
    property var  barScreens: []
    property int  barSide: 0
    property int  barType: 0
    property int  barMenu: 0

    property bool barHideAuto: false
    property bool barHideSmart: true

    property bool barWidgetClockSeconds: false
    property bool barWidgetClock24: true
    property bool barWidgetBatteryValue: true
    property bool barWidgetVolumeValue: false
    property bool barWidgetWindowAppID: false

    property bool dockEnabled: true
    property var  dockScreens: []
    property int  dockSide: 1
    property int  dockType: 0

    property bool dockHideAuto: true
    property bool dockHideSmart: true

    property bool dockMerge: true
    property bool dockBadges: true
    property int  dockIconSize: 46
    property var  dockPinned: []

    property bool islandEnabled: true

    property bool osdEnabled: true
    property int  osdDuration: 2000

    property bool osdTypeBattery: true
    property bool osdTypeBluetooth: true
    property bool osdTypeBrightness: true
    property bool osdTypeLayout: true
    property bool osdTypeNetwork: true
    property bool osdTypeVolume: true

    property bool notificationsEnabled: true
    property var notificationsBlockedApps: []
    property int  notificationsDuration: 5000
    property bool notificationsRememberDnd: false
    property bool notificationsDnd: false
    property double notificationsDndUntil: 0

    property int screenshotMode: 0
    property bool screenshotSave: false

    property bool lockNotifications: true
    property bool lockNotificationsContent: true

    property string shellLanguage: "system"

    property var displays: ({})

    property int idleLock: 120
    property int idleDisplay: 180
    property int idleSuspend: 900

    property int powerProfileBattery: 0
    property int powerProfilePlugged: 1

    property int    nightLightMode: 0
    property int    nightLightTemperature: 5000
    property string nightLightFrom: "20:00"
    property string nightLightTo: "07:00"

    function scrollDelta(pixelDeltaY, angleDeltaY)
    {
        const speed = Math.max(1.0, Math.min(4.0, Number(scrollSpeed) || 1.0));
        if (Math.abs(pixelDeltaY) > 0) return pixelDeltaY * speed;
        return (angleDeltaY / 120.0) * 48.0 * speed;
    }

    function screensShown(key) { return config[key].length === 0 ? Quickshell.screens.map(s => s.name) : config[key] }
    function toggleScreen(key, name, on)
    {
        const all = Quickshell.screens.map(s => s.name);
        const current = screensShown(key);
        const next = all.filter(n => n === name ? on : current.indexOf(n) >= 0);
        if (next.length === 0) return;
        set(key, next.length === all.length ? [] : next);
    }

    property int configVersion: 1
    property var defaults: ({})

    property bool initialized: false

    readonly property string dir: Paths.settingsDir
    readonly property string file: dir + "/settings.json"

    function isOption(key)
    {
        if (typeof config[key] === "function") return false;
        const serviceKeys =
        [
            "defaults",
            "initialized",

            "dir",
            "file",
            "store",
            "saveTimer",
            "ensureConfigDirectory",
            "objectName",
            "reloadableId",
            "children",

            "animationsEnabled",
            "animationsFluid",
        ];
        return serviceKeys.indexOf(key) < 0;
    }

    function clone(v) { return JSON.parse(JSON.stringify(v)) }
    function valid(key, v)
    {
        const d = defaults[key];
        if (key === "wallpaperTransition") return ["none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer", "random"].includes(v);

        if (Array.isArray(d))
            return Array.isArray(v) && v.every(item => typeof item === "string" && item.length > 0);

        if (d !== null && typeof d === "object")
            return v !== null && typeof v === "object" && !Array.isArray(v);

        if (typeof v !== typeof d) return false;
        if (typeof v !== "number") return true;
        if (!Number.isFinite(v)) return false;
        if (key === "powerProfileBattery" || key === "powerProfilePlugged") return Number.isInteger(v) && v >= 0 && v <= 2;
        const ranges = {
            themeStyle: [0, 1], themeAnimations: [0, 2], desktopBlur: [0, 2], desktopEqualizerOpacity: [0.25, 1],
            barSide: [0, 3], dockSide: [0, 3], barType: [0, 3], dockType: [0, 3],
            frameThickness: [0, 8], scrollSpeed: [1, 4], dockIconSize: [16, 128],
            osdDuration: [0, 60000], notificationsDuration: [0, 600000],
            notificationsDndUntil: [0, 8640000000000000],
            idleLock: [0, 86400], idleDisplay: [0, 86400], idleSuspend: [0, 86400],
            nightLightTemperature: [1000, 10000], nightLightMode: [0, 2]
        };
        const range = ranges[key];
        return !range || v >= range[0] && v <= range[1];
    }

    function snapshot()
    {
        const out = {};
        const keys = Object.keys(config);

        for (let i = 0; i < keys.length; i++)
        {
            const key = keys[i];
            if (isOption(key)) out[key] = clone(config[key]);
        }
        return out;
    }

    function applyObject(obj)
    {
        // TODO: config version

        for (const key in obj)
        {
            if (key === "configVersion" || !(key in config) || !isOption(key)) continue;
            if (!valid(key, obj[key])) continue;

            if (JSON.stringify(config[key]) !== JSON.stringify(obj[key])) config[key] = obj[key];
        }
    }
    function applyText(text)
    {
        if (!text) return;

        try
        {
            const obj = JSON.parse(text);
            if (obj !== null && typeof obj === "object") applyObject(obj);
        }
        catch(e)
        {
            console.warn("Config: could not read " + file + ": " + e);
        }
    }

    function set(key, value)
    {
        if (!(key in config) || !isOption(key))
        {
            console.warn("Config: unknown option " + key);
            return;
        }
        if (!valid(key, value))
        {
            console.warn("Config: invalid value for " + key);
            return;
        }
        if (JSON.stringify(config[key]) === JSON.stringify(value)) return;

        config[key] = value;
        saveTimer.restart();
    }

    function reset()
    {
        const keys = Object.keys(defaults);

        for (let i = 0; i < keys.length; i++)
        {
            const key = keys[i];
            if (isOption(key)) config[key] = clone(defaults[key]);
        }
        saveTimer.restart();
    }
    function save() { store.setText(JSON.stringify(snapshot(), null, 2) + "\n") }

    Component.onCompleted:
    {
        defaults = clone(snapshot());
        ensureConfigDirectory.exec(["mkdir", "-p", dir]);
    }

    FileView
    {
        id: store

        blockLoading: true
        watchChanges: true

        onLoaded:
        {
            config.applyText(text());
            config.initialized = true;
        }
        onLoadFailed: function(error)
        {
            if (error === FileViewError.FileNotFound) config.save();
            else console.warn("Config: could not read" + config.file + ": " + FileViewError.toString(error));
            config.initialized = true;
        }
        onFileChanged: if (!saveTimer.running) reload()
    }

    Timer
    {
        id: saveTimer
        interval: 300

        onTriggered: config.save()
    }

    Process
    {
        id: ensureConfigDirectory

        onExited: function(code)
        {
            if (code !== 0)
            {
                console.warn("Config: could not create config directory " + config.dir);
                config.initialized = true;
                return;
            }
            store.path = config.file;
        }
    }
}
