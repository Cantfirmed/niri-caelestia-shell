pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property color colour

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        animate: true
        text: (VPN.connected || VPN.connecting) ? "vpn_key" : "vpn_key_off"
        color: VPN.connected ? Colours.palette.m3primary : root.colour
        fill: VPN.connected ? 1 : 0

        SequentialAnimation on opacity {
            running: VPN.connecting || VPN.disconnecting
            alwaysRunToEnd: true
            loops: Animation.Infinite

            Anim {
                from: 1
                to: 0.3
                duration: Tokens.anim.durations.large
                easing: Tokens.anim.standardAccel
            }
            Anim {
                from: 0.3
                to: 1
                duration: Tokens.anim.durations.large
                easing: Tokens.anim.standardDecel
            }
        }
    }
}
