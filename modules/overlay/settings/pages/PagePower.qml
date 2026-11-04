import QtQuick
import QtQuick.Shapes

import "../../../components"
import "../../../components/settings"
import "../../../core"
import "../../../services"

SettingsPage
{
    id: pagePower

    title: Tr.tr("common.power")
    subtitle: Tr.tr("settings.power.batteryPowerProfilesFromHint")

    Component.onCompleted: ServicePower.refreshDetails()

    SettingsGroup
    {
        title: Tr.tr("common.battery")
        visible: ServicePower.present

        SettingsRow { label: Tr.tr("settings.power.charge");   valueText: ServicePower.percent + "%" + (ServicePower.timeText !== "" ? " · " + ServicePower.timeText : "") }
        SettingsRow { label: Tr.tr("common.status");   valueText: ServicePower.status }
        SettingsRow { label: Tr.tr("common.power");    valueText: ServicePower.infoPower }
        SettingsRow { label: Tr.tr("common.capacity"); valueText: ServicePower.infoCapacity }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.power.last24Hours")
        subtitle: Tr.tr("settings.power.batteryLevelOverTheHint")
        visible: ServicePower.present && ServicePower.history.length > 1

        Item
        {
            id: chart

            width: parent.width
            height: 190

            readonly property real now: Date.now() / 1000
            readonly property real span: 86400

            readonly property real padLeft: 44
            readonly property real padRight: 16
            readonly property real padTop: 16
            readonly property real padBottom: 30
            readonly property real plotW: width - padLeft - padRight
            readonly property real plotH: height - padTop - padBottom

            readonly property var points: ServicePower.history
                .filter(p => p.t >= now - span)
                .concat([{ t: now, v: ServicePower.level, charging: ServicePower.charging }])

            function px(t) { return padLeft + Math.max(0, Math.min(1, (t - (now - span)) / span)) * plotW }
            function py(v) { return padTop + (1 - v) * plotH }

            readonly property var chargingRuns:
            {
                const runs = [];
                let start = -1;
                for (let i = 0; i < points.length; i++)
                {
                    const p = points[i];
                    if (p.charging && start < 0) start = p.t;
                    if (!p.charging && start >= 0) { runs.push([start, p.t]); start = -1; }
                }
                if (start >= 0) runs.push([start, now]);
                return runs;
            }

            Repeater
            {
                model: [0, 0.5, 1]

                Item
                {
                    required property real modelData
                    anchors.fill: parent

                    Rectangle
                    {
                        x: chart.padLeft
                        y: chart.py(parent.modelData)
                        width: chart.plotW
                        height: 1
                        color: Theme.settingsColorLine
                    }
                    ShellText
                    {
                        anchors { right: parent.left; rightMargin: -chart.padLeft + 8 }
                        y: chart.py(parent.modelData) - height / 2
                        label: Math.round(parent.modelData * 100) + "%"
                        size: 10
                        color: Theme.text4
                    }
                }
            }

            Repeater
            {
                model: chart.chargingRuns

                Rectangle
                {
                    required property var modelData
                    x: chart.px(modelData[0])
                    y: chart.padTop
                    width: Math.max(2, chart.px(modelData[1]) - x)
                    height: chart.plotH
                    radius: 3
                    color: Theme.accentShell ? Theme.accentAlpha(0.12) : Theme.inkAlpha(0.05)
                }
            }

            Item
            {
                id: plot
                anchors.fill: parent
                clip: true

                property real reveal: Config.animationsFluid ? 0 : 1
                Component.onCompleted: reveal = 1
                Ease on reveal { duration: 900 }

                Item
                {
                    width: chart.padLeft + chart.plotW * plot.reveal + 2
                    height: parent.height
                    clip: true

                    Shape
                    {
                        width: chart.width
                        height: chart.height
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath
                        {
                            strokeWidth: 0
                            strokeColor: "transparent"
                            fillGradient: LinearGradient
                            {
                                x1: 0; y1: chart.padTop; x2: 0; y2: chart.padTop + chart.plotH
                                GradientStop { position: 0; color: Theme.accentShell ? Theme.accentAlpha(0.32) : Theme.inkAlpha(0.16) }
                                GradientStop { position: 1; color: Theme.accentShell ? Theme.accentAlpha(0.02) : Theme.inkAlpha(0.01) }
                            }
                            PathPolyline
                            {
                                path:
                                {
                                    const pts = chart.points.map(p => Qt.point(chart.px(p.t), chart.py(p.v)));
                                    if (pts.length === 0) return [];
                                    const bottom = chart.padTop + chart.plotH;
                                    return [Qt.point(pts[0].x, bottom)].concat(pts).concat([Qt.point(pts[pts.length - 1].x, bottom)]);
                                }
                            }
                        }
                        ShapePath
                        {
                            strokeWidth: 2
                            strokeColor: Theme.colorAccent
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathPolyline { path: chart.points.map(p => Qt.point(chart.px(p.t), chart.py(p.v))) }
                        }
                    }
                }
            }

            Rectangle
            {
                x: chart.px(chart.now) - width / 2
                y: chart.py(ServicePower.level) - height / 2
                width: 8
                height: 8
                radius: 4
                color: Theme.colorAccent
                opacity: plot.reveal > 0.98 ? 1 : 0
                Smooth on opacity { duration: 200 }
            }

            Repeater
            {
                model: [{ at: 0, label: "24 h ago" }, { at: 0.5, label: "12 h ago" }, { at: 1, label: Tr.tr("settings.power.now") }]

                ShellText
                {
                    required property var modelData
                    x: Math.max(chart.padLeft, Math.min(chart.width - chart.padRight - width, chart.padLeft + modelData.at * chart.plotW - width / 2))
                    y: chart.height - chart.padBottom + 8
                    label: modelData.label
                    size: 10
                    color: Theme.text4
                }
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.power.batteryHealth")
        subtitle: Tr.tr("settings.power.batteriesSlowlyLoseCapacityHint")
        visible: ServicePower.present && ServicePower.healthPercent >= 0

        SettingsRow
        {
            label: Tr.tr("settings.power.health")
            badge: ServicePower.healthPercent >= 80 ? Tr.tr("settings.power.good") : ServicePower.healthPercent >= 60 ? Tr.tr("settings.power.worn") : Tr.tr("settings.power.replaceSoon")
            badgeColor: ServicePower.healthPercent >= 80 ? "transparent" : ServicePower.healthPercent >= 60 ? Theme.colorWarning : Theme.colorCritical
            valueText: ServicePower.healthPercent + "%"
        }
        SettingsRow
        {
            visible: (ServicePower.health.design || 0) > 0
            label: Tr.tr("common.capacity")
            valueText: Tr.tr("settings.power.ofWhenNew").arg((ServicePower.health.full || 0).toFixed(2)).arg((ServicePower.health.design || 0).toFixed(2)).arg(ServicePower.health.unit || "")
        }
        SettingsRow { visible: (ServicePower.health.cycles ?? -1) >= 0; label: Tr.tr("settings.power.chargeCycles"); valueText: String(ServicePower.health.cycles ?? "") }
        SettingsRow
        {
            visible: (ServicePower.health.vendor || ServicePower.health.model || "") !== ""
            label: Tr.tr("settings.power.model")
            valueText: [ServicePower.health.vendor, ServicePower.health.model].filter(s => s).join(" ")
        }
        SettingsRow { visible: (ServicePower.health.technology || "") !== ""; label: Tr.tr("settings.power.type"); valueText: ServicePower.health.technology || "" }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.power.powerMode")

        SettingsRow
        {
            label: Tr.tr("settings.power.energyProfile")
            description: Tr.tr("settings.power.powerSaverLowersConsumptionHint")

            SettingsChoices
            {
                options: ServicePower.profileHasPerformance
                    ? [{ label: Tr.tr("settings.power.powerSaver"), value: 0 }, { label: Tr.tr("common.balanced"), value: 1 }, { label: Tr.tr("common.performance"), value: 2 }]
                    : [{ label: Tr.tr("settings.power.powerSaver"), value: 0 }, { label: Tr.tr("common.balanced"), value: 1 }]
                current: ServicePower.profileID
                onSelected: value => ServicePower.setProfile(value)
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.power.whenIdle")
        subtitle: Tr.tr("settings.power.countedFromTheLastHint")

        SettingsRow
        {
            label: Tr.tr("settings.power.lockAfter")
            description: Tr.tr("settings.power.showsTheLockScreenHint")

            SettingsCombo
            {
                width: 220
                options: [
                    { label: Tr.tr("settings.power.minute").arg(1), value: 60 },
                    { label: Tr.tr("settings.power.minutes").arg(2), value: 120 },
                    { label: Tr.tr("settings.power.minutes").arg(5), value: 300 },
                    { label: Tr.tr("settings.power.minutes").arg(10), value: 600 },
                    { label: Tr.tr("settings.power.minutes").arg(15), value: 900 },
                    { label: Tr.tr("settings.power.minutes").arg(30), value: 1800 },
                    { label: Tr.tr("settings.power.never"), value: 0 }
                ]
                current: Config.idleLock
                onSelected: value => Config.set("idleLock", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.power.turnOffTheScreenAfter")
            description: Tr.tr("settings.power.anyKeyOrMouseMoveTurns")

            SettingsCombo
            {
                width: 220
                options: [
                    { label: Tr.tr("settings.power.minute").arg(1), value: 60 },
                    { label: Tr.tr("settings.power.minutes").arg(2), value: 120 },
                    { label: Tr.tr("settings.power.minutes").arg(3), value: 180 },
                    { label: Tr.tr("settings.power.minutes").arg(5), value: 300 },
                    { label: Tr.tr("settings.power.minutes").arg(10), value: 600 },
                    { label: Tr.tr("settings.power.minutes").arg(15), value: 900 },
                    { label: Tr.tr("settings.power.minutes").arg(30), value: 1800 },
                    { label: Tr.tr("settings.power.hour").arg(1), value: 3600 },
                    { label: Tr.tr("settings.power.never"), value: 0 }
                ]
                current: Config.idleDisplay
                onSelected: value => Config.set("idleDisplay", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.power.sleepAfter")
            description: Config.idleSuspend > 0 && Config.idleDisplay > 0 && Config.idleSuspend <= Config.idleDisplay
                ? Tr.tr("settings.power.theComputerSleepsBefore")
                : Tr.tr("settings.power.savesOpenWorkInHint")

            SettingsCombo
            {
                width: 220
                options: [
                    { label: Tr.tr("settings.power.minutes").arg(5), value: 300 },
                    { label: Tr.tr("settings.power.minutes").arg(10), value: 600 },
                    { label: Tr.tr("settings.power.minutes").arg(15), value: 900 },
                    { label: Tr.tr("settings.power.minutes").arg(30), value: 1800 },
                    { label: Tr.tr("settings.power.minutes").arg(45), value: 2700 },
                    { label: Tr.tr("settings.power.hour").arg(1), value: 3600 },
                    { label: Tr.tr("settings.power.never"), value: 0 }
                ]
                current: Config.idleSuspend
                onSelected: value => Config.set("idleSuspend", value)
            }
        }
    }
}
