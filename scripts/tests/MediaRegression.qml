import QtQuick
import Quickshell

import "common"
import "core"
import "services"

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

    Component.onCompleted: Qt.callLater(() =>
    {
        ServiceMedia.cavaMissing = true;
        Mpris.players = { values: [player] };
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
        const frame = [2000, 1500, 1000].concat(Array(ServiceMedia.bars - 3).fill(0));
        ServiceMedia.ingestLevels(frame.join(";") + ";");
        check(Math.abs(ServiceMedia.levels[0] - 0.92) < 1e-12
              && Math.abs(ServiceMedia.levels[1] - 0.69) < 1e-12
              && Math.abs(ServiceMedia.levels[2] - 0.46) < 1e-12,
              "Audio acquisition flattened loud bands before rendering");
        ServiceMedia.ingestLevels(frame.map(value => value / 2).join(";") + ";");
        check(ServiceMedia.visualizerPeak > 1000 && ServiceMedia.visualizerPeak < 2000 && ServiceMedia.levels[0] < 0.5,
              "Gain jumped to maximum between audio peaks");
        ServiceMedia.ingestLevels("bad;-1;Infinity;");
        check(ServiceMedia.levels.length === ServiceMedia.bars && ServiceMedia.levels.every(value => value === 0),
              "Malformed audio frames escaped normalization");
        Config.equalizerStyle = Enums.EqualizerWaves;
        check(equalizer.style === Enums.EqualizerWaves && ServiceMedia.visualizerUsers === 1, "Global Waves selection changed subscriptions");
        ServiceMedia.levels = [0.2, 0.8, 0.4];
        check(equalizer.levels.length === 7, "Waves ignored the requested sample count");
        const samplePlan = equalizer.samplePlan;
        const waves = equalizer.children.find(item => item.item !== undefined).item;
        check(waves && waves.objectName === "equalizerWaves", "Waves renderer was not loaded");
        check(Math.max(...waves.target) < Math.max(...equalizer.levels), "Waves did not smooth neighboring frequency samples");
        const beforeRetarget = JSON.stringify(waves.values);
        ServiceMedia.levels = [0.8, 0.1, 0.9];
        check(equalizer.samplePlan === samplePlan, "Audio frames recompute the resampling geometry");
        check(waves.settling && JSON.stringify(waves.values) === beforeRetarget, "New samples snapped the wave instead of retargeting its motion");
        const path = waves.curve([0.2, 0.8, 0.4]);
        check(path.startsWith("M 0 40 L 0 ") && path.endsWith("L 100 40 Z") && path.includes(" C "), "Waves are not a closed, curved fill");
        for (const levels of [[0.1, 0.3, 0.9, 0.5, 0.4], [0, 1, 0, 1, 0], [1, 1, 1], [0, 0, 0]])
        {
            const segments = waves.curve(levels).match(/C [^CLZ]+/g).map(segment => segment.slice(2).trim().split(/\s+/).map(Number));
            for (let i = 0; i < segments.length; i++)
            {
                const segment = segments[i];
                for (let j = 1; j < segment.length; j += 2)
                    check(segment[j] >= 0 && segment[j] <= equalizer.height, "Wave curve escaped its render area");
                if (i > 0)
                {
                    const previous = segments[i - 1];
                    check(Math.abs((previous[5] - previous[3]) - (segment[1] - previous[5])) < 1e-9,
                          "Wave segments meet with a sharp change of slope: " + JSON.stringify([previous, segment, levels]));
                }
            }
        }
        waves.advance(1 / 60);
        check(waves.velocities.some(value => Math.abs(value) > 0), "Wave did not ease toward new audio levels");
        const beforeVelocity = JSON.stringify(waves.velocities), beforeValues = JSON.stringify(waves.values);
        ServiceMedia.levels = [0.1, 0.9, 0.2];
        check(JSON.stringify(waves.velocities) === beforeVelocity && JSON.stringify(waves.values) === beforeValues,
              "New audio samples interrupted wave velocity");
        function response(rate)
        {
            waves.values = [0.2, 0.2]; waves.target = [0.8, 0.8]; waves.velocities = [0, 0]; waves.settling = true;
            for (let i = 0; i < rate / 6; i++) waves.advance(1 / rate);
            return waves.values[0];
        }
        const slow = response(30), fast = response(144);
        check(Math.abs(slow - fast) < 1e-9 && slow > 0.2 && slow < 0.8, "Wave smoothing depends on display refresh rate");
        waves.target = [0, 1];
        for (let i = 0; i < 180; i++)
        {
            waves.advance(1 / 60);
            check(waves.values.every(value => value >= 0 && value <= 1), "Wave motion overshot its render area");
        }
        check(!waves.settling && waves.values[0] === 0 && waves.values[1] === 1, "Settled wave retained animation work");
        Config.animationsEnabled = false;
        check(!waves.settling && waves.velocities.every(value => value === 0), "Disabling animations retained wave motion");
        Config.animationsEnabled = true;
        equalizer.bars = 100;
        check(equalizer.levels.length === 32, "Wave complexity is not bounded");
        Config.equalizerStyle = Enums.EqualizerBars;
        check(equalizer.style === Enums.EqualizerBars && equalizer.barCount === 100, "Switching back changed Bars layout");
        equalizer.samples = [0.4, 0.7];
        check(ServiceMedia.visualizerUsers === 0 && equalizer.levels.length === 100, "Preview samples started a live visualizer");
        for (let i = 0; i < 100; i++)
            check(Math.abs(equalizer.levels[i] - (0.4 + 0.3 * i / 99)) < 1e-12, "Cached resampling changed the equalizer shape");
        equalizer.bars = 3;
        equalizer.samples = [2, 1.5, 1];
        check(JSON.stringify(equalizer.levels) === "[1,0.75,0.5]", "Loud audio was cropped instead of scaled proportionally");
        check(equalizer.levelHeight(1) < equalizer.height && equalizer.levelHeight(0.5) === equalizer.levelHeight(1) / 2,
              "Peak heights do not fit the available render area");
        equalizer.height = 10;
        check(equalizer.levelHeight(1) < 10, "Resizing retained the previous pixel height");
        equalizer.samples = [NaN, -1, Infinity];
        check(equalizer.levels.every(value => value === 0), "Invalid audio samples escaped normalization");
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
        check(ServiceMedia.visualizerPeak === 16, "Suspending the visualizer retained stale gain");
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
