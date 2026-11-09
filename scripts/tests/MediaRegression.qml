import QtQuick
import Quickshell

import "common"
import "core"
import "services"
import "src/Visualizer.js" as Visualizer

ShellRoot
{
    id: tests
    property int phase: 0
    property int positionTicks: 0
    property int previousTicks: 0
    property int levelChanges: 0
    property int previousLevels: 0

    function check(condition, message)
    {
        if (!condition)
        {
            console.error("REGRESSION_FAILED", message);
            Qt.quit();
            throw new Error(message);
        }
    }

    QtObject
    {
        id: player
        property string dbusName: "test-player"
        property bool isPlaying: true
        property bool positionSupported: true
        property bool canSeek: true
        property bool lengthSupported: true
        property real position: 12
        property real length: 180
        property string identity: "Player"
        property string trackTitle: "Track"
        property string trackArtist: "Artist"
        property string trackAlbum: "Album"
        property string trackArtUrl: ""
    }
    Connections { target: player; function onPositionChanged() { tests.positionTicks++ } }
    Connections { target: ServiceMedia; function onLevelsChanged() { tests.levelChanges++ } }
    QtObject { id: secondClient }

    Item
    {
        id: parentItem
        width: 200
        height: 100
        Item
        {
            id: presenter
            width: 100
            height: 50
            visible: false
        }
    }
    Equalizer
    {
        id: equalizer
        parent: parentItem
        width: 110
        height: 40
        active: false
    }
    RenderActivity { id: activity; target: presenter }
    readonly property bool visualizerWanted: activity.active && Config.animationsEnabled
    onVisualizerWantedChanged: ServiceMedia.setVisualizerActive(presenter, visualizerWanted)

    function checkShape()
    {
        for (const phase of [0, 0.1, 2.5, 6.28, 10000])
        {
            const actual = Visualizer.points(58, 44, 7, phase);
            check(actual.length === 73, "contour retains original resolution");
            for (let i = 0; i <= 72; i++)
            {
                const angle = i / 72 * Math.PI * 2;
                const radius = 44 + 7 * (0.6 * Math.sin(5 * angle + phase * 2) + 0.4 * Math.sin(3 * angle - phase * 1.3));
                check(Math.abs(actual[i].x - (58 + radius * Math.cos(angle))) < 1e-7, "contour x preserves shape");
                check(Math.abs(actual[i].y - (58 + radius * Math.sin(angle))) < 1e-7, "contour y preserves shape");
            }
        }
    }

    Component.onCompleted: Qt.callLater(() =>
    {
        ServiceMedia.cavaMissing = true;
        Mpris.players = { values: [player] };
        checkShape();
        check(equalizer.barCount === 28, "equalizer derives count from width");
        equalizer.width = 54;
        check(equalizer.barCount === 14, "equalizer responds to resizing");
        equalizer.bars = 7;
        equalizer.width = 100;
        check(equalizer.barCount === 7, "explicit equalizer count survives resizing");
        equalizer.width = 0;
        check(equalizer.barCount === 0 && !equalizer.running, "zero width suspends equalizer");
        equalizer.width = 100;
        equalizer.active = true;
        check(ServiceMedia.visualizerUsers === 1, "equalizer subscribes independently");
        Config.equalizerStyle = Enums.EqualizerWaves;
        check(equalizer.style === Enums.EqualizerWaves && ServiceMedia.visualizerUsers === 1, "Global Waves selection changed subscriptions");
        ServiceMedia.levels = [0.2, 0.8, 0.4];
        check(equalizer.levels.length === 7, "Waves ignored the requested sample count");
        const waves = equalizer.children.find(item => item.item !== undefined).item;
        check(waves && waves.objectName === "equalizerWaves", "Waves renderer was not loaded");
        check(Math.max(...waves.target) < Math.max(...equalizer.levels), "Waves did not smooth neighboring frequency samples");
        const beforeRetarget = JSON.stringify(waves.values);
        ServiceMedia.levels = [0.8, 0.1, 0.9];
        check(waves.settling && JSON.stringify(waves.values) === beforeRetarget, "New samples snapped the wave instead of retargeting its motion");
        const path = waves.curve([0.2, 0.8, 0.4]);
        check(path.startsWith("M 0 40 L 0 ") && path.endsWith("L 100 40 Z") && path.includes(" C "), "Waves are not a closed, curved fill");
        equalizer.bars = 100;
        check(equalizer.levels.length === 32, "Wave complexity is not bounded");
        Config.equalizerStyle = Enums.EqualizerBars;
        check(equalizer.style === Enums.EqualizerBars && equalizer.barCount === 100, "Switching back changed Bars layout");
        equalizer.samples = [0.4, 0.7];
        check(ServiceMedia.visualizerUsers === 0 && equalizer.levels.length === 100, "Preview samples started a live visualizer");
        equalizer.samples = null;
        equalizer.visible = false;
        check(ServiceMedia.visualizerUsers === 0, "hidden equalizer releases shared cava");
        equalizer.visible = true;
        equalizer.active = false;
        presenter.visible = true;
        check(activity.active && ServiceMedia.visualizerRunning, "visible media starts visualizer");
        ServiceMedia.setVisualizerActive(presenter, true);
        check(ServiceMedia.visualizerUsers === 1, "duplicate visualizer subscriptions ignored");
        parentItem.opacity = 0;
        check(!activity.active && !ServiceMedia.visualizerRunning, "transparent ancestor stops visualizer");
        parentItem.opacity = 1;
        check(ServiceMedia.visualizerRunning, "visualizer resumes when shown");
        ServiceLock.locked = true;
        check(!ServiceMedia.visualizerRunning, "lock screen suspends background visualizers");
        ServiceLock.locked = false;
        check(ServiceMedia.visualizerRunning, "unlock resumes visualizers");
        Config.animationsEnabled = false;
        check(!ServiceMedia.visualizerRunning, "disabled animations stop visualizer work");
        Config.animationsEnabled = true;
        presenter.visible = false;
        check(ServiceMedia.visualizerUsers === 0 && !ServiceMedia.visualizerRunning, "hidden media releases visualizer");
        previousTicks = positionTicks;
        previousLevels = levelChanges;
        verify.start();
    })

    Timer
    {
        id: verify
        interval: 1100
        onTriggered:
        {
            if (tests.phase === 0)
            {
                tests.check(tests.positionTicks === tests.previousTicks, "no media position polling without a visible progress consumer");
                tests.check(tests.levelChanges === tests.previousLevels, "hidden visualizers produce no level updates");
                ServiceMedia.setPositionActive(presenter, true);
                ServiceMedia.setPositionActive(presenter, true);
                ServiceMedia.setPositionActive(secondClient, true);
                tests.check(ServiceMedia.positionUsers === 2, "progress observers are unique");
                tests.previousTicks = tests.positionTicks;
                tests.phase = 1;
                restart();
            }
            else if (tests.phase === 1)
            {
                tests.check(tests.positionTicks > tests.previousTicks, "visible progress is refreshed");
                ServiceMedia.setPositionActive(presenter, false);
                ServiceMedia.setPositionActive(presenter, false);
                tests.check(ServiceMedia.positionUsers === 1, "removing one observer keeps the other");
                ServiceMedia.setPositionActive(secondClient, false);
                tests.check(ServiceMedia.positionUsers === 0, "last observer stops position polling");
                tests.previousTicks = tests.positionTicks;
                tests.phase = 2;
                restart();
            }
            else
            {
                tests.check(tests.positionTicks === tests.previousTicks, "hidden progress causes no polling callbacks");
                Mpris.players = { values: [] };
                console.log("REGRESSIONS_PASSED media activity");
                Qt.quit();
            }
        }
    }
    Timer { interval: 6000; running: true; onTriggered: { console.error("REGRESSION_FAILED media timeout"); Qt.quit(); } }
}
