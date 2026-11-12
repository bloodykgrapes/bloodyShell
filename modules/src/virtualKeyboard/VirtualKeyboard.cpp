#include <QCoreApplication>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QInputMethodEvent>
#include <QKeyEvent>
#include <QQmlExtensionPlugin>
#include <QSocketNotifier>
#include <QTemporaryFile>
#include <QVariantList>
#include <qqml.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>
#include <xkbcommon/xkbcommon-compose.h>
#include <clocale>
#include <cstdlib>
#include <cstring>
#include "virtual-keyboard-client.h"

class VirtualKeyboardEngine : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString layout READ layout WRITE setLayout NOTIFY layoutChanged)
    Q_PROPERTY(QString variant READ variant WRITE setVariant NOTIFY layoutChanged)
    Q_PROPERTY(bool symbols READ symbols WRITE setSymbols NOTIFY layoutChanged)
    Q_PROPERTY(bool local READ local WRITE setLocal NOTIFY localChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY statusChanged)
    Q_PROPERTY(QString error READ error NOTIFY statusChanged)
    Q_PROPERTY(QVariantList rows READ rows NOTIFY layoutChanged)

public:
    explicit VirtualKeyboardEngine(QObject *parent = nullptr) : QObject(parent)
    {
        clock.start();
        context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
        const char *locale = std::setlocale(LC_CTYPE, nullptr);
        if (context) composeTable = xkb_compose_table_new_from_locale(context, locale ? locale : "C.UTF-8", XKB_COMPOSE_COMPILE_NO_FLAGS);
        if (composeTable) compose = xkb_compose_state_new(composeTable, XKB_COMPOSE_STATE_NO_FLAGS);
        rebuild();
    }
    ~VirtualKeyboardEngine() override
    {
        disconnectDisplay();
        if (compose) xkb_compose_state_unref(compose);
        if (composeTable) xkb_compose_table_unref(composeTable);
        if (state) xkb_state_unref(state);
        if (keymap) xkb_keymap_unref(keymap);
        if (context) xkb_context_unref(context);
    }

    QString layout() const { return code; }
    QString variant() const { return variation; }
    bool symbols() const { return symbolMode; }
    bool local() const { return localMode; }
    bool ready() const { return state && validMap && failure.isEmpty() && (localMode || keyboard); }
    QString error() const { return failure; }
    void setLayout(const QString &value) { if (code != value) { code = value; rebuild(); } }
    void setVariant(const QString &value) { if (variation != value) { variation = value; rebuild(); } }
    void setSymbols(bool value) { if (symbolMode != value) { symbolMode = value; rebuild(); } }
    void setLocal(bool value)
    {
        if (localMode == value) return;
        localMode = value;
        if (localMode) { disconnectDisplay(); if (validMap) failure.clear(); }
        emit localChanged();
        emit statusChanged();
    }

    Q_INVOKABLE void connectDisplay()
    {
        if (localMode || display || !validMap) return;
        display = wl_display_connect(nullptr);
        if (!display) { fail(QStringLiteral("Cannot connect to the Wayland display.")); return; }
        registry = wl_display_get_registry(display);
        static const wl_registry_listener listener = {global, globalRemoved};
        wl_registry_add_listener(registry, &listener, this);
        if (wl_display_roundtrip(display) < 0 || !seat || !manager)
        {
            disconnectDisplay();
            fail(QStringLiteral("The compositor does not provide a virtual keyboard."));
            return;
        }
        keyboard = zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(manager, seat);
        failure.clear();
        upload();
        notifier = new QSocketNotifier(wl_display_get_fd(display), QSocketNotifier::Read, this);
        connect(notifier, &QSocketNotifier::activated, this, [this] {
            if (wl_display_dispatch(display) < 0)
            {
                disconnectDisplay();
                fail(QStringLiteral("The virtual keyboard lost its Wayland connection."));
            }
        });
        emit statusChanged();
    }

    Q_INVOKABLE void disconnectDisplay()
    {
        delete notifier;
        notifier = nullptr;
        if (keyboard) zwp_virtual_keyboard_v1_destroy(keyboard);
        if (manager) zwp_virtual_keyboard_manager_v1_destroy(manager);
        if (seat) wl_seat_destroy(seat);
        if (registry) wl_registry_destroy(registry);
        if (display) { wl_display_flush(display); wl_display_disconnect(display); }
        keyboard = nullptr; manager = nullptr; seat = nullptr; registry = nullptr; display = nullptr;
        emit statusChanged();
    }

    QVariantList rows() const
    {
        if (!state || !validMap) return {};
        // Linux evdev positions; labels come from the selected XKB layout and variant.
        static const QList<QList<int>> positions = {
            {41, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13},
            {16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27},
            {30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 43},
            {44, 45, 46, 47, 48, 49, 50, 51, 52, 53}
        };
        QVariantList result;
        for (const auto &row : positions)
        {
            QVariantList keys;
            for (int key : row)
                keys.append(QVariantMap{{"code", key}, {"lower", label(key, false, false)}, {"upper", label(key, true, false)}, {"alternate", label(key, false, false, true)}});
            result.append(QVariant::fromValue(keys));
        }
        return result;
    }

    Q_INVOKABLE QString label(int key, bool shifted, bool caps, bool alternate = false) const
    {
        if (!state) return {};
        setModifiers(shifted, caps, alternate);
        char buffer[128] = {};
        xkb_state_key_get_utf8(state, key + 8, buffer, sizeof buffer);
        const auto text = QString::fromUtf8(buffer);
        if (!text.isEmpty()) return text;
        const auto sym = xkb_state_key_get_one_sym(state, key + 8);
        if (sym >= XKB_KEY_dead_grave && sym <= XKB_KEY_dead_currency)
        {
            const char *marks[] = {"`", "´", "^", "~", "¯", "˘", "˙", "¨", "˚", "˝", "ˇ", "¸", "˛"};
            const auto offset = sym - XKB_KEY_dead_grave;
            return offset < sizeof marks / sizeof *marks ? QString::fromUtf8(marks[offset]) : QStringLiteral("◌");
        }
        return {};
    }

    Q_INVOKABLE bool tap(int key, bool shifted = false, bool caps = false, bool alternate = false)
    {
        if (key < 1 || key > 255 || !ready()) return false;
        setModifiers(shifted, caps, alternate);
        if (localMode)
        {
            QObject *target = QGuiApplication::focusObject();
            if (!target) return false;
            const int qtKey = specialKey(key);
            if (qtKey)
            {
                const auto modifiers = shifted ? Qt::ShiftModifier : Qt::NoModifier;
                QKeyEvent down(QEvent::KeyPress, qtKey, modifiers);
                QCoreApplication::sendEvent(target, &down);
                // Submission may destroy the input; do not retain the old pointer.
                if (QGuiApplication::focusObject() == target)
                {
                    QKeyEvent up(QEvent::KeyRelease, qtKey, modifiers);
                    QCoreApplication::sendEvent(target, &up);
                }
            }
            else
            {
                auto text = label(key, shifted, caps, alternate);
                if (compose)
                {
                    xkb_compose_state_feed(compose, xkb_state_key_get_one_sym(state, key + 8));
                    const auto status = xkb_compose_state_get_status(compose);
                    if (status == XKB_COMPOSE_COMPOSING) return true;
                    if (status == XKB_COMPOSE_COMPOSED)
                    {
                        char buffer[128] = {};
                        xkb_compose_state_get_utf8(compose, buffer, sizeof buffer);
                        text = QString::fromUtf8(buffer);
                    }
                    if (status != XKB_COMPOSE_NOTHING) xkb_compose_state_reset(compose);
                    if (status == XKB_COMPOSE_CANCELLED) return true;
                }
                QInputMethodEvent event;
                event.setCommitString(text);
                QCoreApplication::sendEvent(target, &event);
            }
        }
        else
        {
            zwp_virtual_keyboard_v1_modifiers(keyboard, mask(shifted, alternate), 0, caps ? mod(XKB_MOD_NAME_CAPS) : 0, 0);
            const auto time = uint32_t(clock.elapsed());
            zwp_virtual_keyboard_v1_key(keyboard, time, key, 1);
            zwp_virtual_keyboard_v1_key(keyboard, time, key, 0);
            zwp_virtual_keyboard_v1_modifiers(keyboard, 0, 0, 0, 0);
            if (wl_display_flush(display) < 0 && wl_display_get_error(display))
            {
                disconnectDisplay();
                fail(QStringLiteral("Could not send the key to the compositor."));
                return false;
            }
        }
        return true;
    }

    Q_INVOKABLE void reset()
    {
        if (compose) xkb_compose_state_reset(compose);
        if (state) setModifiers(false, false, false);
    }

signals:
    void layoutChanged();
    void localChanged();
    void statusChanged();

private:
    static int specialKey(int key)
    {
        switch (key)
        {
        case 1: return Qt::Key_Escape; case 14: return Qt::Key_Backspace; case 15: return Qt::Key_Tab;
        case 28: return Qt::Key_Return; case 111: return Qt::Key_Delete;
        case 105: return Qt::Key_Left; case 106: return Qt::Key_Right;
        case 103: return Qt::Key_Up; case 108: return Qt::Key_Down;
        case 102: return Qt::Key_Home; case 107: return Qt::Key_End;
        default: return 0;
        }
    }
    uint32_t mod(const char *name) const
    {
        const auto index = xkb_keymap_mod_get_index(keymap, name);
        return index == XKB_MOD_INVALID || index >= 32 ? 0 : uint32_t(1) << index;
    }
    uint32_t mask(bool shifted, bool alternate) const { return (shifted ? mod(XKB_MOD_NAME_SHIFT) : 0) | (alternate ? mod("Mod5") : 0); }
    void setModifiers(bool shifted, bool caps, bool alternate) const { xkb_state_update_mask(state, mask(shifted, alternate), 0, caps ? mod(XKB_MOD_NAME_CAPS) : 0, 0, 0, 0); }
    void fail(const QString &message) { failure = message; emit statusChanged(); }
    void rebuild()
    {
        validMap = false;
        if (!context) { fail(QStringLiteral("Could not initialize keyboard layouts.")); return; }
        const auto layoutBytes = (symbolMode ? QStringLiteral("us") : code).toUtf8();
        const auto variantBytes = (symbolMode ? QString() : variation).toUtf8();
        const xkb_rule_names names = {nullptr, nullptr, layoutBytes.constData(), variantBytes.constData(), ""};
        auto *next = xkb_keymap_new_from_names(context, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
        if (!next) { fail(QStringLiteral("Could not load the selected keyboard layout.")); return; }
        auto *nextState = xkb_state_new(next);
        if (!nextState) { xkb_keymap_unref(next); fail(QStringLiteral("Could not initialize the selected keyboard layout.")); return; }
        if (state) xkb_state_unref(state);
        if (keymap) xkb_keymap_unref(keymap);
        keymap = next; state = nextState;
        validMap = true;
        if (compose) xkb_compose_state_reset(compose);
        failure.clear();
        upload();
        emit layoutChanged();
        emit statusChanged();
    }
    void upload()
    {
        if (!keyboard || !keymap) return;
        char *serialized = xkb_keymap_get_as_string(keymap, XKB_KEYMAP_FORMAT_TEXT_V1);
        if (!serialized) { fail(QStringLiteral("Could not prepare the keyboard layout.")); return; }
        const auto size = std::strlen(serialized) + 1;
        QTemporaryFile file;
        if (!file.open() || file.write(serialized, size) != qint64(size) || !file.flush())
            fail(QStringLiteral("Could not share the keyboard layout with the compositor."));
        else
        {
            zwp_virtual_keyboard_v1_keymap(keyboard, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, file.handle(), uint32_t(size));
            wl_display_flush(display);
        }
        std::free(serialized);
    }
    static void global(void *data, wl_registry *registry, uint32_t name, const char *interface, uint32_t)
    {
        auto *self = static_cast<VirtualKeyboardEngine *>(data);
        if (std::strcmp(interface, wl_seat_interface.name) == 0 && !self->seat)
        {
            self->seat = static_cast<wl_seat *>(wl_registry_bind(registry, name, &wl_seat_interface, 1));
            static const wl_seat_listener listener = {[](void *, wl_seat *, uint32_t) {}, [](void *, wl_seat *, const char *) {}};
            wl_seat_add_listener(self->seat, &listener, self);
        }
        else if (std::strcmp(interface, zwp_virtual_keyboard_manager_v1_interface.name) == 0)
            self->manager = static_cast<zwp_virtual_keyboard_manager_v1 *>(wl_registry_bind(registry, name, &zwp_virtual_keyboard_manager_v1_interface, 1));
    }
    static void globalRemoved(void *, wl_registry *, uint32_t) {}

    QString code = QStringLiteral("us"), variation, failure;
    bool localMode = false, symbolMode = false, validMap = false;
    xkb_context *context = nullptr;
    xkb_keymap *keymap = nullptr;
    xkb_state *state = nullptr;
    xkb_compose_table *composeTable = nullptr;
    xkb_compose_state *compose = nullptr;
    wl_display *display = nullptr;
    wl_registry *registry = nullptr;
    wl_seat *seat = nullptr;
    zwp_virtual_keyboard_manager_v1 *manager = nullptr;
    zwp_virtual_keyboard_v1 *keyboard = nullptr;
    QSocketNotifier *notifier = nullptr;
    QElapsedTimer clock;
};

class VirtualKeyboardPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override { qmlRegisterType<VirtualKeyboardEngine>(uri, 1, 0, "VirtualKeyboardEngine"); }
};

#include "virtualkeyboard.moc"
