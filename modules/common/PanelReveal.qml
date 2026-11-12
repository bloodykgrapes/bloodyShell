import QtQuick

QtObject
{
    id: reveal

    required property int delay
    property bool wanted: true
    property bool ready: true
    property bool revealed: true

    function update()
    {
        if (wanted) { hideDelay.stop(); revealed = true; }
        else if (ready) hideDelay.restart();
        else hideDelay.stop();
    }

    onWantedChanged: update()
    onReadyChanged: update()
    Component.onCompleted: update()

    readonly property Timer hideDelay: Timer
    {
        interval: reveal.delay
        onTriggered: reveal.revealed = reveal.wanted
    }
}
