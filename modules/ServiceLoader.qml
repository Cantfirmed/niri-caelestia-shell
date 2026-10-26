import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

Scope {
    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily

        IdleInhibitor;
        GameMode;
        Notifs;
        Players;
        Brightness;
        NiriBlur.init();
        NiriTiling.init();
        BiriShaders.init();
        Biri.init();
        Weather.reload();
        VPN;
        Tailscale;
        BluetoothAudio;
    }
}
