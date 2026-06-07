#pragma once

#include "configobject.hpp"

namespace caelestia::config {

class ExtraConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, manga, true)
    CONFIG_PROPERTY(bool, novel, true)

public:
    explicit ExtraConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace caelestia::config
