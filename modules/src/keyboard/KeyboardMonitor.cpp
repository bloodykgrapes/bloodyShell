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
        ready.invalidate();
        seenAlt = false;
        emit targetWindowChanged();
    }

    void setListening(bool value)
    {
        if (enabled == value) return;
        enabled = value;
        ready.invalidate();
        seenAlt = false;
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
        if (!target || !target->isVisible()) return;
        if (!target->isActive())
        {
            if (ready.isValid()) finish();
            return;
        }
        if (!ready.isValid()) ready.start();
        const bool current = QGuiApplication::keyboardModifiers().testFlag(Qt::AltModifier);
        if (current)
        {
            seenAlt = true;
            return;
        }
        if (seenAlt || ready.elapsed() >= 64) finish();
    }

    void finish()
    {
        probe.stop();
        emit released();
    }

    QPointer<QQuickWindow> target;
    QTimer probe;
    QElapsedTimer ready;
    bool enabled = false;
    bool seenAlt = false;
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
