pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Singleton
{
    id: config

    readonly property bool animationsEnabled: !motionReduce && motionStyle !== Enums.MotionDirect
    readonly property bool animationsFluid:   animationsEnabled && motionStyle === Enums.MotionGlide

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

    property int  themeStyle: Enums.ThemeAuto
    property int  shellSurface: Enums.SurfaceSolid
    property int  themeAccentMode: Enums.AccentAuto
    property real accentHue: 210
    property int  highlightStyle: Enums.HighlightOrange
    property real highlightHue: 30
    property bool motionReduce: false
    property int  motionStyle: Enums.MotionGlide
    property real motionSpeed: 1
    property bool focusFollowsPointer: false
    property bool pointerJumpsToFocus: false
    property bool kittyColorsEnabled: false

    property int frameThickness: 6
    property int frameRadius: 22
    property int menuRadius: 22
    property int surfaceBlurStrength: 60
    property int surfaceBlurGrain: 20

    property string wallpaperCurrent: ""
    property string wallpaperDirectory: Paths.home + "/Pictures/Wallpapers"
    property string wallpaperTransition: "random"
    property bool wallpaperTransitionEnabled: true
    property int  wallpaperTransitionDuration: 1000
    property bool wallpaperShuffle: false
    property int  wallpaperShuffleMinutes: 30
    property int  wallpaperLivePause: Enums.PauseNever
    property bool wallpaperPauseOnBattery: false
    property bool wallpaperBlur: false
    property int  wallpaperBlurStrength: 35
    property bool overviewBackdrop: true
    property int  overviewBlur: 55

    property int equalizerStyle: 0
    property real desktopEqualizerOpacity: 1

    property string primaryScreen: ""
    property var  barScreens: []
    property int  barSide: 0
    property int  barType: Enums.BarCenter
    property bool barAttach: true
    property int  barAttachCurve: 60
    property bool barHoverExpand: false
    property int  barHoverDelay: 250
    property int  barScrollAction: 0

    property bool barHideAuto: false
    property bool barHideSmart: true

    property bool barWidgetClockSeconds: false
    property bool barWidgetClock24: true
    property bool barWidgetBatteryValue: true
    property bool barWidgetVolumeValue: false
    property int  barWidgetWindowMode: 0
    property bool barWidgetKeyboardLayout: true

    property var  dockScreens: []
    property int  dockSide: 1
    property int  dockType: Enums.InFrame
    property bool dockAttach: true
    property int  dockAttachCurve: 60

    property bool dockHideAuto: true
    property bool dockHideSmart: true

    property bool dockMerge: true
    property bool dockBadges: true
    property int  dockIconSize: 46
    property var  dockPinned: []

    property bool islandEnabled: true
    property bool islandMedia: true
    property bool islandRecordingIndicator: true
    property bool islandCameraIndicator: true

    property int  osdDuration: 2000

    property bool osdTypeBattery: true
    property bool osdTypeBluetooth: true
    property bool osdTypeBrightness: true
    property bool osdTypeLayout: true
    property bool osdTypeNetwork: true
    property bool osdTypeVolume: true
    property bool osdTypeUSB: true
    property bool osdTypeScreenshot: true
    property bool osdTypeRecording: true

    property bool notificationsEnabled: true
    property var notificationsBlockedApps: []
    property int  notificationsDuration: 6000

    property int screenshotMode: 0
    property string screenshotsPath: screenshotsDefault()
    property string screenshotsFileName: "%Y-%m-%d_%H.%M.%S"
    property string screenshotsAction: "copy"
    property bool screenshotsInstantly: false
    property string recordingsPath: recordingsDefault()
    property string recordingsFileName: "%Y-%m-%d_%H.%M.%S"

    function screenshotsDefault()
    {
        const directory = decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.PicturesLocation)).replace(/^file:\/\//, ""));
        return (directory || Paths.home + "/Pictures") + "/Screenshots";
    }

    function recordingsDefault()
    {
        const directory = decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.MoviesLocation)).replace(/^file:\/\//, ""));
        return (directory || Paths.home + "/Videos") + "/Recordings";
    }

    property bool lockNotifications: false
    property bool lockNotificationsContent: true
    property bool lockAvatar: true
    property bool lockName: true
    property bool lockClock: true
    property bool lockDate: true
    property bool lockMusic: true

    property int launcherStyle: Enums.LauncherFloating
    property int launcherMaxResults: 8

    property int windowGaps: 10
    property bool windowCenterFocused: false
    property bool windowCenterSingle: false
    property real windowOverviewSize: 0.75
    property int windowRadius: 16
    property bool windowClipContent: true
    property int windowBorderMode: Enums.BorderOff
    property int windowBorderWidth: 2
    property int windowBorderColor: Enums.ColorGray
    property int windowFocusColor: Enums.ColorAccent
    property real windowFocusOpacity: 1
    property real windowUnfocusedOpacity: 1
    property bool windowBlurBehind: true
    property bool windowAnimate: true
    property int windowAnimationStyle: Enums.WindowNiri
    property real windowAnimationSpeed: 1

    property string shellLanguage: "system"

    property var displays: ({})

    property int idleLock: 120
    property int idleDisplay: 180
    property int idleSuspend: 900
    property bool lockBeforeSleep: true

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
        if (key === "configVersion" || !Object.prototype.hasOwnProperty.call(defaults, key)) return false;
        const d = defaults[key];
        if (key === "wallpaperTransition") return ["none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer", "random"].includes(v);
        if (key === "screenshotMode") return v === Enums.ScreenshotArea || v === Enums.ScreenshotScreen;
        if (key === "screenshotsAction") return ["copy", "save"].includes(v);
        if (key === "screenshotsPath") return typeof v === "string" && (v === "" || /^(\/|~\/)/.test(v)) && !/[\x00-\x1f]/.test(v);
        if (key === "recordingsPath") return typeof v === "string" && (v === "" || /^(\/|~\/)/.test(v)) && !/[\x00-\x1f]/.test(v);
        if (key === "screenshotsFileName" || key === "recordingsFileName")
            return typeof v === "string" && v.trim() !== "" && v.length <= 200 && !/[\\/\x00-\x1f]/.test(v);
        if (key === "primaryScreen")
            return typeof v === "string" && v.length <= 255 && !/[\x00-\x1f]/.test(v);

        if (Array.isArray(d))
            return Array.isArray(v) && v.every(item => typeof item === "string" && item.length > 0);

        if (d !== null && typeof d === "object")
            return v !== null && typeof v === "object" && !Array.isArray(v);

        if (typeof v !== typeof d) return false;
        if (typeof v !== "number") return true;
        if (!Number.isFinite(v)) return false;
        if (!["scrollSpeed", "desktopEqualizerOpacity", "motionSpeed", "accentHue", "highlightHue",
              "windowOverviewSize", "windowFocusOpacity", "windowUnfocusedOpacity", "windowAnimationSpeed"].includes(key)
            && !Number.isInteger(v)) return false;
        const ranges = {
            themeStyle: [0, 3], themeAccentMode: [0, 1], highlightStyle: [0, 4], accentHue: [0, 360], highlightHue: [0, 360],
            motionStyle: [0, 2], motionSpeed: [0.25, 2], shellSurface: [0, 2], desktopEqualizerOpacity: [0.25, 1],
            barSide: [0, 3], dockSide: [0, 3], barType: [Enums.BarCenter, Enums.BarWaves], dockType: [Enums.PanelDisabled, Enums.OutFrame],
            updateCheck: [0, 4], equalizerStyle: [0, 1], barWidgetWindowMode: [0, 2],
            powerProfileBattery: [0, 2], powerProfilePlugged: [0, 2],
            frameThickness: [0, 8], frameRadius: [0, 30], menuRadius: [0, 30], surfaceBlurStrength: [0, 100], surfaceBlurGrain: [0, 100],
            wallpaperTransitionDuration: [200, 3000], wallpaperShuffleMinutes: [5, 360], wallpaperLivePause: [0, 2],
            wallpaperBlurStrength: [0, 100], overviewBlur: [0, 100], barAttachCurve: [40, 80], barHoverDelay: [150, 500],
            barScrollAction: [0, 2], dockAttachCurve: [40, 80], launcherStyle: [0, 1], launcherMaxResults: [3, 14],
            windowGaps: [0, 64], windowOverviewSize: [0.25, 1.5], windowRadius: [0, 20], windowBorderMode: [0, 2],
            windowBorderWidth: [1, 8], windowBorderColor: [0, 2], windowFocusColor: [0, 2], windowFocusOpacity: [0.5, 1],
            windowUnfocusedOpacity: [0.5, 1], windowAnimationStyle: [0, 2], windowAnimationSpeed: [0.25, 2],
            scrollSpeed: [1, 4], dockIconSize: [16, 128],
            osdDuration: [0, 60000], notificationsDuration: [0, 600000],
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
        if (obj === null || typeof obj !== "object" || Array.isArray(obj)) return;
        const settings = Object.assign(Object.create(null), obj);
        if (settings.wallpaperBlur === undefined && [1, 2].includes(settings.desktopBlur))
            settings.wallpaperBlur = true;
        if (!valid("barType", settings.barType))
        {
            if (settings.barType === Enums.PanelDisabled || settings.barEnabled === false) settings.barType = Enums.BarCenter;
            else if (settings.barType === Enums.OutFrame)
            {
                settings.barType = Enums.BarWaves;
                if (settings.barAttach === undefined) settings.barAttach = false;
            }
            else if (settings.barType === 2) settings.barType = Enums.BarFull;
            else if (settings.barType === Enums.InFrame || settings.barType === 3 || settings.barEnabled === true)
                settings.barType = Enums.BarWaves;
        }
        if (settings.dockEnabled === false) settings.dockType = Enums.PanelDisabled;
        else if (settings.dockType === 2 || settings.dockType === 3 || settings.dockEnabled === true && !valid("dockType", settings.dockType))
            settings.dockType = Enums.InFrame;
        if (obj.kittyColorsEnabled === undefined && ["default", "wallpaper", "custom"].includes(obj.kittyColorMode))
            kittyColorsEnabled = obj.kittyColorMode !== "default";
        for (const key of Object.keys(settings))
        {
            const value = settings[key];
            if (!valid(key, value)) continue;

            if (JSON.stringify(config[key]) !== JSON.stringify(value)) config[key] = value;
        }
    }
    function applyText(text)
    {
        if (!text) return;

        try
        {
            applyObject(JSON.parse(text));
        }
        catch(e)
        {
            console.warn("Config: could not read " + file + ": " + e);
        }
    }

    function set(key, value)
    {
        if (key === "configVersion" || !Object.prototype.hasOwnProperty.call(defaults, key))
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
            // A watched read can finish after another local edit. Its older
            // snapshot must not replace values waiting to be saved.
            if (!config.initialized || !saveTimer.running) config.applyText(text());
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
