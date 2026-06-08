qml_module(caelestia-internal
    URI Caelestia.Internal
    SOURCES
        circularbuffer.cpp
        circularindicatormanager.cpp
        linearindicatormanager.cpp
        logindmanager.cpp
        sparklineitem.cpp
        visualiserbars.cpp
        niriipc.cpp
        nirisocket.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Network
        Qt::DBus
)
