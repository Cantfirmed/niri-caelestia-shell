#pragma once

#include "common.hpp"
#include "settings/objectnode.hpp"

namespace caelestia::config {

class ExtraConfig : public settings::ObjectNode {
    CONFIG_NODE(ExtraConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, manga, true)
    CONFIG_PROPERTY(bool, novel, true)
};


} // namespace caelestia::config
