#pragma once

#include <qobject.h>
#include <qqmlintegration.h>

#include "tokens.hpp"

namespace caelestia::config {

namespace detail {

void connectAllPropertySignals(const QObject* source, QObject* target, const char* signalName);

} // namespace detail

class ScaledBarTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(int innerWidth READ innerWidth NOTIFY valuesChanged)
    Q_PROPERTY(int windowPreviewSize READ windowPreviewSize NOTIFY valuesChanged)
    Q_PROPERTY(int trayMenuWidth READ trayMenuWidth NOTIFY valuesChanged)
    Q_PROPERTY(int batteryWidth READ batteryWidth NOTIFY valuesChanged)
    Q_PROPERTY(int networkWidth READ networkWidth NOTIFY valuesChanged)
    Q_PROPERTY(int audioWidth READ audioWidth NOTIFY valuesChanged)
    Q_PROPERTY(int kbLayoutWidth READ kbLayoutWidth NOTIFY valuesChanged)

public:
    explicit ScaledBarTokens(QObject* parent = nullptr)
        : QObject(parent) {}

    void bind(const BarTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] int innerWidth() const;
    [[nodiscard]] int windowPreviewSize() const;
    [[nodiscard]] int trayMenuWidth() const;
    [[nodiscard]] int batteryWidth() const;
    [[nodiscard]] int networkWidth() const;
    [[nodiscard]] int audioWidth() const;
    [[nodiscard]] int kbLayoutWidth() const;

signals:
    void valuesChanged();

private:
    const BarTokens* m_tokens = nullptr;
    qreal m_scale = 1.0;
};

class ScaledDashboardTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(int tabIndicatorHeight READ tabIndicatorHeight NOTIFY valuesChanged)
    Q_PROPERTY(int tabIndicatorSpacing READ tabIndicatorSpacing NOTIFY valuesChanged)
    Q_PROPERTY(int userWidth READ userWidth NOTIFY valuesChanged)
    Q_PROPERTY(int logoSize READ logoSize NOTIFY valuesChanged)
    Q_PROPERTY(int uptimeSize READ uptimeSize NOTIFY valuesChanged)
    Q_PROPERTY(int dateTimeWidth READ dateTimeWidth NOTIFY valuesChanged)
    Q_PROPERTY(int mediaWidth READ mediaWidth NOTIFY valuesChanged)
    Q_PROPERTY(int mediaProgressSweep READ mediaProgressSweep NOTIFY valuesChanged)
    Q_PROPERTY(int mediaProgressThickness READ mediaProgressThickness NOTIFY valuesChanged)
    Q_PROPERTY(int resourceProgressThickness READ resourceProgressThickness NOTIFY valuesChanged)
    Q_PROPERTY(int weatherWidth READ weatherWidth NOTIFY valuesChanged)
    Q_PROPERTY(int mediaCoverArtSize READ mediaCoverArtSize NOTIFY valuesChanged)
    Q_PROPERTY(int mediaTabWidth READ mediaTabWidth NOTIFY valuesChanged)
    Q_PROPERTY(int mediaTabHeight READ mediaTabHeight NOTIFY valuesChanged)
    Q_PROPERTY(int mediaSectionWidth READ mediaSectionWidth NOTIFY valuesChanged)
    Q_PROPERTY(int perfHeroCardWidth READ perfHeroCardWidth NOTIFY valuesChanged)
    Q_PROPERTY(int perfUsageShapeSize READ perfUsageShapeSize NOTIFY valuesChanged)
    Q_PROPERTY(int perfStorageTextWidth READ perfStorageTextWidth NOTIFY valuesChanged)
    Q_PROPERTY(int perfNetworkCardWidth READ perfNetworkCardWidth NOTIFY valuesChanged)
    Q_PROPERTY(int perfNetworkCardHeight READ perfNetworkCardHeight NOTIFY valuesChanged)
    Q_PROPERTY(int perfBattWidth READ perfBattWidth NOTIFY valuesChanged)
    Q_PROPERTY(int perfBattWidthSingle READ perfBattWidthSingle NOTIFY valuesChanged)
    Q_PROPERTY(int perfBattHeight READ perfBattHeight NOTIFY valuesChanged)
    Q_PROPERTY(int perfPlaceholderWidth READ perfPlaceholderWidth NOTIFY valuesChanged)

public:
    explicit ScaledDashboardTokens(QObject* parent = nullptr)
        : QObject(parent) {}

    void bind(const DashboardTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] int tabIndicatorHeight() const;
    [[nodiscard]] int tabIndicatorSpacing() const;
    [[nodiscard]] int userWidth() const;
    [[nodiscard]] int logoSize() const;
    [[nodiscard]] int uptimeSize() const;
    [[nodiscard]] int dateTimeWidth() const;
    [[nodiscard]] int mediaWidth() const;
    [[nodiscard]] int mediaProgressSweep() const;
    [[nodiscard]] int mediaProgressThickness() const;
    [[nodiscard]] int resourceProgressThickness() const;
    [[nodiscard]] int weatherWidth() const;
    [[nodiscard]] int mediaCoverArtSize() const;
    [[nodiscard]] int mediaTabWidth() const;
    [[nodiscard]] int mediaTabHeight() const;
    [[nodiscard]] int mediaSectionWidth() const;
    [[nodiscard]] int perfHeroCardWidth() const;
    [[nodiscard]] int perfUsageShapeSize() const;
    [[nodiscard]] int perfStorageTextWidth() const;
    [[nodiscard]] int perfNetworkCardWidth() const;
    [[nodiscard]] int perfNetworkCardHeight() const;
    [[nodiscard]] int perfBattWidth() const;
    [[nodiscard]] int perfBattWidthSingle() const;
    [[nodiscard]] int perfBattHeight() const;
    [[nodiscard]] int perfPlaceholderWidth() const;

signals:
    void valuesChanged();

private:
    const DashboardTokens* m_tokens = nullptr;
    qreal m_scale = 1.0;
};

class ScaledLauncherTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(int itemWidth READ itemWidth NOTIFY valuesChanged)
    Q_PROPERTY(int itemHeight READ itemHeight NOTIFY valuesChanged)
    Q_PROPERTY(int wallpaperWidth READ wallpaperWidth NOTIFY valuesChanged)
    Q_PROPERTY(int wallpaperHeight READ wallpaperHeight NOTIFY valuesChanged)

public:
    explicit ScaledLauncherTokens(QObject* parent = nullptr)
        : QObject(parent) {}

    void bind(const LauncherTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] int itemWidth() const;
    [[nodiscard]] int itemHeight() const;
    [[nodiscard]] int wallpaperWidth() const;
    [[nodiscard]] int wallpaperHeight() const;

signals:
    void valuesChanged();

private:
    const LauncherTokens* m_tokens = nullptr;
    qreal m_scale = 1.0;
};

class ScaledNotifsTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(int width READ width NOTIFY valuesChanged)
    Q_PROPERTY(int image READ image NOTIFY valuesChanged)
    Q_PROPERTY(int badge READ badge NOTIFY valuesChanged)

public:
    explicit ScaledNotifsTokens(QObject* parent = nullptr)
        : QObject(parent) {}

    void bind(const NotifsTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] int width() const;
    [[nodiscard]] int image() const;
    [[nodiscard]] int badge() const;

signals:
    void valuesChanged();

private:
    const NotifsTokens* m_tokens = nullptr;
    qreal m_scale = 1.0;
};

class ScaledOsdTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(int sliderWidth READ sliderWidth NOTIFY valuesChanged)
    Q_PROPERTY(int sliderHeight READ sliderHeight NOTIFY valuesChanged)

public:
    explicit ScaledOsdTokens(QObject* parent = nullptr)
        : QObject(parent) {}

    void bind(const OsdTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] int sliderWidth() const;
    [[nodiscard]] int sliderHeight() const;

signals:
    void valuesChanged();

private:
    const OsdTokens* m_tokens = nullptr;
    qreal m_scale = 1.0;
};

class ScaledSessionTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(int button READ button NOTIFY valuesChanged)

public:
    explicit ScaledSessionTokens(QObject* parent = nullptr)
        : QObject(parent) {}

    void bind(const SessionTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] int button() const;

signals:
    void valuesChanged();

private:
    const SessionTokens* m_tokens = nullptr;
    qreal m_scale = 1.0;
};

class ScaledSidebarTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(int width READ width NOTIFY valuesChanged)

public:
    explicit ScaledSidebarTokens(QObject* parent = nullptr)
        : QObject(parent) {}

    void bind(const SidebarTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] int width() const;

signals:
    void valuesChanged();

private:
    const SidebarTokens* m_tokens = nullptr;
    qreal m_scale = 1.0;
};

class ScaledUtilitiesTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(int width READ width NOTIFY valuesChanged)
    Q_PROPERTY(int toastWidth READ toastWidth NOTIFY valuesChanged)

public:
    explicit ScaledUtilitiesTokens(QObject* parent = nullptr)
        : QObject(parent) {}

    void bind(const UtilitiesTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] int width() const;
    [[nodiscard]] int toastWidth() const;

signals:
    void valuesChanged();

private:
    const UtilitiesTokens* m_tokens = nullptr;
    qreal m_scale = 1.0;
};

class ScaledLockTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(qreal heightMult READ heightMult NOTIFY valuesChanged)
    Q_PROPERTY(qreal ratio READ ratio NOTIFY valuesChanged)
    Q_PROPERTY(int centerWidth READ centerWidth NOTIFY valuesChanged)
    Q_PROPERTY(int showWeatherDetailsHeight READ showWeatherDetailsHeight NOTIFY valuesChanged)
    Q_PROPERTY(int showForecastHeight READ showForecastHeight NOTIFY valuesChanged)
    Q_PROPERTY(int forecastItemWidth READ forecastItemWidth NOTIFY valuesChanged)
    Q_PROPERTY(int largeLogoWidth READ largeLogoWidth NOTIFY valuesChanged)
    Q_PROPERTY(int largeFontWidth READ largeFontWidth NOTIFY valuesChanged)
    Q_PROPERTY(int fetch4LinesHeight READ fetch4LinesHeight NOTIFY valuesChanged)
    Q_PROPERTY(int fetch3LinesHeight READ fetch3LinesHeight NOTIFY valuesChanged)
    Q_PROPERTY(int showColourBoxRowHeight READ showColourBoxRowHeight NOTIFY valuesChanged)

public:
    explicit ScaledLockTokens(QObject* parent = nullptr)
        : QObject(parent) {}

    void bind(const LockTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] qreal heightMult() const;
    [[nodiscard]] qreal ratio() const;
    [[nodiscard]] int centerWidth() const;
    [[nodiscard]] int showWeatherDetailsHeight() const;
    [[nodiscard]] int showForecastHeight() const;
    [[nodiscard]] int forecastItemWidth() const;
    [[nodiscard]] int largeLogoWidth() const;
    [[nodiscard]] int largeFontWidth() const;
    [[nodiscard]] int fetch4LinesHeight() const;
    [[nodiscard]] int fetch3LinesHeight() const;
    [[nodiscard]] int showColourBoxRowHeight() const;

signals:
    void valuesChanged();

private:
    const LockTokens* m_tokens = nullptr;
    qreal m_scale = 1.0;
};

class ScaledWInfoTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(qreal heightMult READ heightMult NOTIFY valuesChanged)
    Q_PROPERTY(qreal detailsWidth READ detailsWidth NOTIFY valuesChanged)

public:
    explicit ScaledWInfoTokens(QObject* parent = nullptr)
        : QObject(parent) {}

    void bind(const WInfoTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] qreal heightMult() const;
    [[nodiscard]] qreal detailsWidth() const;

signals:
    void valuesChanged();

private:
    const WInfoTokens* m_tokens = nullptr;
    qreal m_scale = 1.0;
};

class ScaledNexusTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(qreal heightMult READ heightMult NOTIFY valuesChanged)
    Q_PROPERTY(qreal ratio READ ratio NOTIFY valuesChanged)
    Q_PROPERTY(int minWidth READ minWidth NOTIFY valuesChanged)
    Q_PROPERTY(int minHeight READ minHeight NOTIFY valuesChanged)
    Q_PROPERTY(int maxNavWidth READ maxNavWidth NOTIFY valuesChanged)
    Q_PROPERTY(int maxContentWidth READ maxContentWidth NOTIFY valuesChanged)
    Q_PROPERTY(int popupWidth READ popupWidth NOTIFY valuesChanged)
    Q_PROPERTY(int minPopupHeight READ minPopupHeight NOTIFY valuesChanged)
    Q_PROPERTY(int maxPopupHeight READ maxPopupHeight NOTIFY valuesChanged)
    Q_PROPERTY(int networkShowEthDetailWidth READ networkShowEthDetailWidth NOTIFY valuesChanged)
    Q_PROPERTY(int networkShowVpnDetailWidth READ networkShowVpnDetailWidth NOTIFY valuesChanged)
    Q_PROPERTY(int maxDialogWidth READ maxDialogWidth NOTIFY valuesChanged)
    Q_PROPERTY(int maxDialogHeight READ maxDialogHeight NOTIFY valuesChanged)
    Q_PROPERTY(int textFieldWidth READ textFieldWidth NOTIFY valuesChanged)
    Q_PROPERTY(int smallTextFieldWidth READ smallTextFieldWidth NOTIFY valuesChanged)

public:
    explicit ScaledNexusTokens(QObject* parent = nullptr)
        : QObject(parent) {}

    void bind(const NexusTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] qreal heightMult() const;
    [[nodiscard]] qreal ratio() const;
    [[nodiscard]] int minWidth() const;
    [[nodiscard]] int minHeight() const;
    [[nodiscard]] int maxNavWidth() const;
    [[nodiscard]] int maxContentWidth() const;
    [[nodiscard]] int popupWidth() const;
    [[nodiscard]] int minPopupHeight() const;
    [[nodiscard]] int maxPopupHeight() const;
    [[nodiscard]] int networkShowEthDetailWidth() const;
    [[nodiscard]] int networkShowVpnDetailWidth() const;
    [[nodiscard]] int maxDialogWidth() const;
    [[nodiscard]] int maxDialogHeight() const;
    [[nodiscard]] int textFieldWidth() const;
    [[nodiscard]] int smallTextFieldWidth() const;

signals:
    void valuesChanged();

private:
    const NexusTokens* m_tokens = nullptr;
    qreal m_scale = 1.0;
};

class ScaledSizeTokens : public QObject {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(caelestia::config::ScaledBarTokens* bar READ bar CONSTANT FINAL)
    Q_PROPERTY(caelestia::config::ScaledDashboardTokens* dashboard READ dashboard CONSTANT FINAL)
    Q_PROPERTY(caelestia::config::ScaledLauncherTokens* launcher READ launcher CONSTANT FINAL)
    Q_PROPERTY(caelestia::config::ScaledNotifsTokens* notifs READ notifs CONSTANT FINAL)
    Q_PROPERTY(caelestia::config::ScaledOsdTokens* osd READ osd CONSTANT FINAL)
    Q_PROPERTY(caelestia::config::ScaledSessionTokens* session READ session CONSTANT FINAL)
    Q_PROPERTY(caelestia::config::ScaledSidebarTokens* sidebar READ sidebar CONSTANT FINAL)
    Q_PROPERTY(caelestia::config::ScaledUtilitiesTokens* utilities READ utilities CONSTANT FINAL)
    Q_PROPERTY(caelestia::config::ScaledLockTokens* lock READ lock CONSTANT FINAL)
    Q_PROPERTY(caelestia::config::ScaledWInfoTokens* winfo READ winfo CONSTANT FINAL)
    Q_PROPERTY(caelestia::config::ScaledNexusTokens* nexus READ nexus CONSTANT FINAL)

public:
    explicit ScaledSizeTokens(QObject* parent = nullptr);

    void bind(const SizeTokens* tokens);
    void setScale(qreal scale);

    [[nodiscard]] ScaledBarTokens* bar() const { return m_bar; }
    [[nodiscard]] ScaledDashboardTokens* dashboard() const { return m_dashboard; }
    [[nodiscard]] ScaledLauncherTokens* launcher() const { return m_launcher; }
    [[nodiscard]] ScaledNotifsTokens* notifs() const { return m_notifs; }
    [[nodiscard]] ScaledOsdTokens* osd() const { return m_osd; }
    [[nodiscard]] ScaledSessionTokens* session() const { return m_session; }
    [[nodiscard]] ScaledSidebarTokens* sidebar() const { return m_sidebar; }
    [[nodiscard]] ScaledUtilitiesTokens* utilities() const { return m_utilities; }
    [[nodiscard]] ScaledLockTokens* lock() const { return m_lock; }
    [[nodiscard]] ScaledWInfoTokens* winfo() const { return m_winfo; }
    [[nodiscard]] ScaledNexusTokens* nexus() const { return m_nexus; }

private:
    ScaledBarTokens* m_bar;
    ScaledDashboardTokens* m_dashboard;
    ScaledLauncherTokens* m_launcher;
    ScaledNotifsTokens* m_notifs;
    ScaledOsdTokens* m_osd;
    ScaledSessionTokens* m_session;
    ScaledSidebarTokens* m_sidebar;
    ScaledUtilitiesTokens* m_utilities;
    ScaledLockTokens* m_lock;
    ScaledWInfoTokens* m_winfo;
    ScaledNexusTokens* m_nexus;
};

} // namespace caelestia::config
