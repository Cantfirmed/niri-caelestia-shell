pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.utils
import qs.services

Singleton {
    id: root

    property list<var> cards: []

    readonly property var activeCard: {
        if (cards.length === 0) return null;
        const sinkName = Pipewire.defaultAudioSink?.name ?? "";
        for (const card of cards) {
            const addrClean = card.address ? card.address.replace(/:/g, "_") : "";
            if (addrClean && sinkName.includes(addrClean)) {
                return card;
            }
        }
        return cards[0];
    }

    readonly property bool hasBluetoothAudio: cards.length > 0
    property bool isRefreshing: pactlProc.running

    function getCardForDevice(device: BluetoothDevice): var {
        if (!device) return null;
        const devAddr = (device.address || "").toLowerCase();
        for (const card of cards) {
            if ((card.address || "").toLowerCase() === devAddr) {
                return card;
            }
        }
        return null;
    }

    function refresh(): void {
        if (!pactlProc.running) {
            pactlProc.running = true;
        }
    }

    function parseCodecProfile(pname: string, pinfo: var): var {
        const desc = pinfo.description || "";
        const match = desc.match(/codec\s+([^)]+)/i);
        let codec = match ? match[1].trim() : "";
        if (!codec) {
            if (pname === "a2dp-sink") {
                codec = desc.toLowerCase().includes("aptx") ? "aptX HD" : "A2DP Sink";
            } else if (pname.startsWith("a2dp-sink-")) {
                const sub = pname.slice("a2dp-sink-".length);
                if (sub === "sbc_xq") codec = "SBC-XQ";
                else if (sub === "aptx") codec = "aptX";
                else if (sub === "aptx_hd") codec = "aptX HD";
                else codec = sub.toUpperCase();
            } else if (pname.startsWith("headset-")) {
                codec = "Headset (" + pname.slice("headset-".length) + ")";
            } else {
                codec = desc;
            }
        }
        if (codec === "MSBC") codec = "mSBC";

        const isHeadset = pname.toLowerCase().includes("headset") ||
                          desc.toLowerCase().includes("hsp") ||
                          desc.toLowerCase().includes("hfp");

        return {
            id: pname,
            codec: codec,
            description: desc,
            isHeadset: isHeadset,
            mode: isHeadset ? Tr.trCtx("Headset / Mic (HFP)", "audio codec mode") : Tr.trCtx("High Fidelity (A2DP)", "audio codec mode"),
            priority: pinfo.priority || 0,
            available: pinfo.available !== false
        };
    }

    function parseCards(data: var): void {
        if (!Array.isArray(data)) return;
        const result = [];
        for (const card of data) {
            const isBt = (card.properties && card.properties["device.bus"] === "bluetooth") ||
                         (card.name && card.name.startsWith("bluez_card"));
            if (!isBt) continue;

            const cardName = card.name;
            const props = card.properties || {};
            const desc = props["device.description"] || props["device.alias"] || cardName;
            const address = props["api.bluez5.address"] || props["device.string"] || "";
            const activeProfile = card.active_profile || "";

            const profiles = [];
            const rawProfiles = card.profiles || {};
            for (const [pname, pinfo] of Object.entries(rawProfiles)) {
                if (pname === "off" || pname === "pro-audio") continue;
                profiles.push(parseCodecProfile(pname, pinfo));
            }

            const rankCodec = function(c) {
                const lower = c.toLowerCase();
                if (lower.includes("ldac")) return 1;
                if (lower.includes("aptx hd") || lower === "aptx-hd") return 2;
                if (lower.includes("aptx adaptive")) return 3;
                if (lower.includes("aptx")) return 4;
                if (lower.includes("aac")) return 5;
                if (lower.includes("sbc-xq")) return 6;
                if (lower.includes("sbc")) return 7;
                if (lower.includes("opus")) return 8;
                if (lower.includes("lc3")) return 9;
                return 15;
            };

            profiles.sort((a, b) => {
                if (a.isHeadset !== b.isHeadset) {
                    return a.isHeadset ? 1 : -1;
                }
                const rankA = rankCodec(a.codec);
                const rankB = rankCodec(b.codec);
                if (rankA !== rankB) return rankA - rankB;
                return b.priority - a.priority;
            });

            let activeCodecName = "";
            for (const p of profiles) {
                if (p.id === activeProfile) {
                    activeCodecName = p.codec;
                    break;
                }
            }

            result.push({
                index: card.index,
                name: cardName,
                description: desc,
                address: address,
                activeProfile: activeProfile,
                activeCodecName: activeCodecName,
                profiles: profiles
            });
        }
        root.cards = result;
    }

    function setProfile(cardName: string, profileId: string): void {
        Quickshell.execDetached(["pactl", "set-card-profile", cardName, profileId]);

        // Optimistic UI update
        for (let i = 0; i < root.cards.length; i++) {
            const c = root.cards[i];
            if (c.name === cardName) {
                c.activeProfile = profileId;
                for (const p of c.profiles) {
                    if (p.id === profileId) {
                        c.activeCodecName = p.codec;
                        Toaster.toast(
                            Tr.tr("Bluetooth Codec"),
                            Tr.tr("%1: switched to %2").arg(c.description).arg(p.codec),
                            "headphones"
                        );
                        break;
                    }
                }
            }
        }
        root.cards = [...root.cards];

        // Re-sync after PipeWire completes renegotiation
        refreshTimer.restart();
    }

    Timer {
        id: refreshTimer
        interval: 600
        repeat: false
        onTriggered: root.refresh()
    }

    Connections {
        target: Bluetooth.devices
        function onValuesChanged() {
            root.refresh();
        }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            root.refresh();
        }
    }

    Process {
        id: pactlProc
        command: ["pactl", "--format=json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.parseCards(data);
                } catch (e) {
                    console.warn("BluetoothAudio JSON parse error:", e);
                }
            }
        }
    }

    Component.onCompleted: {
        root.refresh();
    }
}
