#include "scaledsizes.hpp"

#include <cmath>
#include <qmetaobject.h>

#include "rootnodes.hpp"

namespace caelestia::config {

namespace detail {

void connectAllPropertySignals(const QObject* source, QObject* target, const char* signalName) {
    if (!source)
        return;

    const auto* meta = source->metaObject();
    const int slotIdx = target->metaObject()->indexOfSignal(signalName);

    for (int i = meta->propertyOffset(); i < meta->propertyCount(); ++i) {
        const auto prop = meta->property(i);
        if (prop.hasNotifySignal())
            QObject::connect(source, prop.notifySignal(), target, target->metaObject()->method(slotIdx));
    }
}

} // namespace detail

namespace {

int scaleInt(int value, qreal scale) {
    return value == 0 ? 0 : static_cast<int>(std::round(value * scale));
}

} // namespace

#define IMPL_SCALED_CLASS(Name, SourceType)                                                                            \
    void Name::bind(const SourceType* tokens) {                                                                        \
        if (m_tokens == tokens)                                                                                        \
            return;                                                                                                    \
        if (m_tokens)                                                                                                  \
            disconnect(m_tokens, nullptr, this, nullptr);                                                              \
        m_tokens = tokens;                                                                                             \
        detail::connectAllPropertySignals(tokens, this, "valuesChanged()");                                            \
        emit valuesChanged();                                                                                          \
    }                                                                                                                  \
    void Name::setScale(qreal scale) {                                                                                 \
        if (qFuzzyCompare(m_scale + 1.0, scale + 1.0))                                                                 \
            return;                                                                                                    \
        m_scale = scale;                                                                                               \
        emit valuesChanged();                                                                                          \
    }

#define IMPL_INT(Class, prop)                                                                                          \
    int Class::prop() const {                                                                                          \
        return m_tokens ? scaleInt(m_tokens->prop(), m_scale) : 0;                                                     \
    }

#define IMPL_UNSCALED_INT(Class, prop)                                                                                 \
    int Class::prop() const {                                                                                          \
        return m_tokens ? m_tokens->prop() : 0;                                                                        \
    }

#define IMPL_UNSCALED_REAL(Class, prop)                                                                                \
    qreal Class::prop() const {                                                                                        \
        return m_tokens ? m_tokens->prop() : 0.0;                                                                      \
    }

#define IMPL_SCALED_REAL(Class, prop)                                                                                  \
    qreal Class::prop() const {                                                                                        \
        return m_tokens ? m_tokens->prop() * m_scale : 0.0;                                                            \
    }

IMPL_SCALED_CLASS(ScaledBarTokens, BarTokens)
IMPL_INT(ScaledBarTokens, innerWidth)
IMPL_INT(ScaledBarTokens, windowPreviewSize)
IMPL_INT(ScaledBarTokens, trayMenuWidth)
IMPL_INT(ScaledBarTokens, batteryWidth)
IMPL_INT(ScaledBarTokens, networkWidth)
IMPL_INT(ScaledBarTokens, audioWidth)
IMPL_INT(ScaledBarTokens, kbLayoutWidth)

IMPL_SCALED_CLASS(ScaledDashboardTokens, DashboardTokens)
IMPL_INT(ScaledDashboardTokens, tabIndicatorHeight)
IMPL_INT(ScaledDashboardTokens, tabIndicatorSpacing)
IMPL_INT(ScaledDashboardTokens, userWidth)
IMPL_INT(ScaledDashboardTokens, logoSize)
IMPL_INT(ScaledDashboardTokens, uptimeSize)
IMPL_INT(ScaledDashboardTokens, dateTimeWidth)
IMPL_INT(ScaledDashboardTokens, mediaWidth)
IMPL_UNSCALED_INT(ScaledDashboardTokens, mediaProgressSweep)
IMPL_INT(ScaledDashboardTokens, mediaProgressThickness)
IMPL_INT(ScaledDashboardTokens, resourceProgressThickness)
IMPL_INT(ScaledDashboardTokens, weatherWidth)
IMPL_INT(ScaledDashboardTokens, mediaCoverArtSize)
IMPL_INT(ScaledDashboardTokens, mediaTabWidth)
IMPL_INT(ScaledDashboardTokens, mediaTabHeight)
IMPL_INT(ScaledDashboardTokens, mediaSectionWidth)
IMPL_INT(ScaledDashboardTokens, perfHeroCardWidth)
IMPL_INT(ScaledDashboardTokens, perfUsageShapeSize)
IMPL_INT(ScaledDashboardTokens, perfStorageTextWidth)
IMPL_INT(ScaledDashboardTokens, perfNetworkCardWidth)
IMPL_INT(ScaledDashboardTokens, perfNetworkCardHeight)
IMPL_INT(ScaledDashboardTokens, perfBattWidth)
IMPL_INT(ScaledDashboardTokens, perfBattWidthSingle)
IMPL_INT(ScaledDashboardTokens, perfBattHeight)
IMPL_INT(ScaledDashboardTokens, perfPlaceholderWidth)

IMPL_SCALED_CLASS(ScaledLauncherTokens, LauncherTokens)
IMPL_INT(ScaledLauncherTokens, itemWidth)
IMPL_INT(ScaledLauncherTokens, itemHeight)
IMPL_INT(ScaledLauncherTokens, wallpaperWidth)
IMPL_INT(ScaledLauncherTokens, wallpaperHeight)

IMPL_SCALED_CLASS(ScaledNotifsTokens, NotifsTokens)
IMPL_INT(ScaledNotifsTokens, width)
int ScaledNotifsTokens::image() const {
    return scaleInt(TokensSingleton::instance()->sizes()->notifs()->image(), m_scale);
}
IMPL_INT(ScaledNotifsTokens, badge)

IMPL_SCALED_CLASS(ScaledOsdTokens, OsdTokens)
IMPL_INT(ScaledOsdTokens, sliderWidth)
IMPL_INT(ScaledOsdTokens, sliderHeight)

IMPL_SCALED_CLASS(ScaledSessionTokens, SessionTokens)
IMPL_INT(ScaledSessionTokens, button)

IMPL_SCALED_CLASS(ScaledSidebarTokens, SidebarTokens)
IMPL_INT(ScaledSidebarTokens, width)

IMPL_SCALED_CLASS(ScaledUtilitiesTokens, UtilitiesTokens)
IMPL_INT(ScaledUtilitiesTokens, width)
IMPL_INT(ScaledUtilitiesTokens, toastWidth)

IMPL_SCALED_CLASS(ScaledLockTokens, LockTokens)
IMPL_SCALED_REAL(ScaledLockTokens, heightMult)
IMPL_UNSCALED_REAL(ScaledLockTokens, ratio)
IMPL_INT(ScaledLockTokens, centerWidth)
IMPL_INT(ScaledLockTokens, showWeatherDetailsHeight)
IMPL_INT(ScaledLockTokens, showForecastHeight)
IMPL_INT(ScaledLockTokens, forecastItemWidth)
IMPL_INT(ScaledLockTokens, largeLogoWidth)
IMPL_INT(ScaledLockTokens, largeFontWidth)
IMPL_INT(ScaledLockTokens, fetch4LinesHeight)
IMPL_INT(ScaledLockTokens, fetch3LinesHeight)
IMPL_INT(ScaledLockTokens, showColourBoxRowHeight)

IMPL_SCALED_CLASS(ScaledWInfoTokens, WInfoTokens)
IMPL_SCALED_REAL(ScaledWInfoTokens, heightMult)
IMPL_SCALED_REAL(ScaledWInfoTokens, detailsWidth)

IMPL_SCALED_CLASS(ScaledNexusTokens, NexusTokens)
IMPL_SCALED_REAL(ScaledNexusTokens, heightMult)
IMPL_UNSCALED_REAL(ScaledNexusTokens, ratio)
IMPL_INT(ScaledNexusTokens, minWidth)
IMPL_INT(ScaledNexusTokens, minHeight)
IMPL_INT(ScaledNexusTokens, maxNavWidth)
IMPL_INT(ScaledNexusTokens, maxContentWidth)
IMPL_INT(ScaledNexusTokens, popupWidth)
IMPL_INT(ScaledNexusTokens, minPopupHeight)
IMPL_INT(ScaledNexusTokens, maxPopupHeight)
IMPL_INT(ScaledNexusTokens, networkShowEthDetailWidth)
IMPL_INT(ScaledNexusTokens, networkShowVpnDetailWidth)
IMPL_INT(ScaledNexusTokens, maxDialogWidth)
IMPL_INT(ScaledNexusTokens, maxDialogHeight)
IMPL_INT(ScaledNexusTokens, textFieldWidth)
IMPL_INT(ScaledNexusTokens, smallTextFieldWidth)

#undef IMPL_SCALED_CLASS
#undef IMPL_INT
#undef IMPL_UNSCALED_INT
#undef IMPL_UNSCALED_REAL
#undef IMPL_SCALED_REAL

ScaledSizeTokens::ScaledSizeTokens(QObject* parent)
    : QObject(parent)
    , m_bar(new ScaledBarTokens(this))
    , m_dashboard(new ScaledDashboardTokens(this))
    , m_launcher(new ScaledLauncherTokens(this))
    , m_notifs(new ScaledNotifsTokens(this))
    , m_osd(new ScaledOsdTokens(this))
    , m_session(new ScaledSessionTokens(this))
    , m_sidebar(new ScaledSidebarTokens(this))
    , m_utilities(new ScaledUtilitiesTokens(this))
    , m_lock(new ScaledLockTokens(this))
    , m_winfo(new ScaledWInfoTokens(this))
    , m_nexus(new ScaledNexusTokens(this)) {}

void ScaledSizeTokens::bind(const SizeTokens* tokens) {
    m_bar->bind(tokens ? tokens->bar() : nullptr);
    m_dashboard->bind(tokens ? tokens->dashboard() : nullptr);
    m_launcher->bind(tokens ? tokens->launcher() : nullptr);
    m_notifs->bind(tokens ? tokens->notifs() : nullptr);
    m_osd->bind(tokens ? tokens->osd() : nullptr);
    m_session->bind(tokens ? tokens->session() : nullptr);
    m_sidebar->bind(tokens ? tokens->sidebar() : nullptr);
    m_utilities->bind(tokens ? tokens->utilities() : nullptr);
    m_lock->bind(tokens ? tokens->lock() : nullptr);
    m_winfo->bind(tokens ? tokens->winfo() : nullptr);
    m_nexus->bind(tokens ? tokens->nexus() : nullptr);
}

void ScaledSizeTokens::setScale(qreal scale) {
    m_bar->setScale(scale);
    m_dashboard->setScale(scale);
    m_launcher->setScale(scale);
    m_notifs->setScale(scale);
    m_osd->setScale(scale);
    m_session->setScale(scale);
    m_sidebar->setScale(scale);
    m_utilities->setScale(scale);
    m_lock->setScale(scale);
    m_winfo->setScale(scale);
    m_nexus->setScale(scale);
}

} // namespace caelestia::config
