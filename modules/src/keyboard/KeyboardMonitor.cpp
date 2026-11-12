#include <QElapsedTimer>
#include <QGuiApplication>
#include <QQmlExtensionPlugin>
#include <QPointer>
#include <QQuickWindow>
#include <QTimer>
#include <qqml.h>

class KeyboardMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QQuickWindow *targetWindow READ targetWindow WRITE setTargetWindow NOTIFY targetWindowChanged)
    Q_PROPERTY(bool listening READ listening WRITE setListening NOTIFY listeningChanged)

public:
    explicit KeyboardMonitor(QObject *parent = nullptr) : QObject(parent)
    {
        probe.setInterval(16);
        connect(&probe, &QTimer::timeout, this, &KeyboardMonitor::sample);
    }

    QQuickWindow *targetWindow() const { return target; }
    bool listening() const { return enabled; }

    void setTargetWindow(QQuickWindow *window)
    {
        if (target == window) return;
        target = window;
        releasedSince.invalidate();
        emit targetWindowChanged();
    }

    void setListening(bool value)
    {
        if (enabled == value) return;
        enabled = value;
        releasedSince.invalidate();
        if (enabled) probe.start();
        else probe.stop();
        emit listeningChanged();
    }

signals:
    void targetWindowChanged();
    void listeningChanged();
    void released();

private:
    void sample()
    {
        // Focusing the next client can briefly interrupt layer-shell keyboard focus.
        // Neither that handoff nor cached key-event modifiers means Alt was released.
        if (!target || !target->isVisible() || !target->isActive())
        {
            releasedSince.invalidate();
            return;
        }
        const bool current = QGuiApplication::queryKeyboardModifiers().testFlag(Qt::AltModifier);
        if (current)
        {
            releasedSince.invalidate();
            return;
        }
        if (!releasedSince.isValid()) releasedSince.start();
        else if (releasedSince.elapsed() >= 64) finish();
    }

    void finish()
    {
        probe.stop();
        emit released();
    }

    QPointer<QQuickWindow> target;
    QTimer probe;
    QElapsedTimer releasedSince;
    bool enabled = false;
};

class KeyboardPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<KeyboardMonitor>(uri, 1, 0, "KeyboardMonitor");
    }
};

#include "keyboard.moc"
