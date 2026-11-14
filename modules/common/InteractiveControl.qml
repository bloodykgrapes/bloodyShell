import QtQuick
import QtQuick.Templates as T

T.Control
{
    hoverEnabled: enabled

    function focusFor(reason)
    {
        forceActiveFocus(reason);
        focusReason = reason;
    }
}
