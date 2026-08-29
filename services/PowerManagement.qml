pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia
import Caelestia.Config
import Caelestia.Services

Singleton {
    id: root

    property alias autoBalance: props.autoBalance
    property alias lowBatteryThreshold: props.lowBatteryThreshold
    property alias highLoadThreshold: props.highLoadThreshold
    property alias highTempThreshold: props.highTempThreshold

    readonly property int profile: PowerProfiles.profile
    readonly property string profileName: {
        switch (PowerProfiles.profile) {
            case PowerProfile.PowerSaver:
                return qsTr("Power Saver");
            case PowerProfile.Performance:
                return qsTr("Performance");
            case PowerProfile.Balanced:
            default:
                return qsTr("Balanced");
        }
    }
    readonly property string profileIcon: {
        switch (PowerProfiles.profile) {
            case PowerProfile.PowerSaver:
                return "energy_savings_leaf";
            case PowerProfile.Performance:
                return "rocket_launch";
            case PowerProfile.Balanced:
            default:
                return "balance";
        }
    }

    readonly property real cpuPercentage: Cpu.percentage
    readonly property real cpuTemperature: Cpu.temperature

    // Keep Cpu monitoring active when autoBalance is on
    ServiceRef {
        service: root.autoBalance ? Cpu : null
    }

    PersistentProperties {
        id: props

        property bool autoBalance: false
        property real lowBatteryThreshold: 0.25
        property real highLoadThreshold: 0.50
        property real highTempThreshold: 85.0
        property int cooldownDuration: 8

        reloadableId: "powerManagement"
    }

    property int _highLoadTicks: 0
    property int _cooldownTicks: 0

    function setAutoBalance(enabled: bool): void {
        props.autoBalance = enabled;
        _highLoadTicks = 0;
        _cooldownTicks = 0;
        if (enabled) {
            evaluate();
        }
    }

    function toggleAutoBalance(): void {
        setAutoBalance(!props.autoBalance);
    }

    function setManualProfile(profile: int): void {
        props.autoBalance = false;
        _highLoadTicks = 0;
        _cooldownTicks = 0;
        PowerProfiles.profile = profile;
    }

    function evaluate(): void {
        if (!props.autoBalance)
            return;

        let target = PowerProfile.Balanced;
        const temp = Cpu.temperature;
        const load = Cpu.percentage;

        // Battery operation
        if (UPower.onBattery) {
            const pct = UPower.displayDevice.isLaptopBattery ? UPower.displayDevice.percentage : 1.0;
            if (pct <= props.lowBatteryThreshold || (temp > 0 && temp >= props.highTempThreshold)) {
                target = PowerProfile.PowerSaver;
            } else {
                target = PowerProfile.Balanced;
            }
            _highLoadTicks = 0;
            _cooldownTicks = 0;
        } else {
            // AC / Plugged in operation: dynamic CPU load & thermal balancing
            // 1. Thermal ceiling protection: if CPU is overheating (> highTempThreshold), stay in Balanced
            if (temp > 0 && temp >= props.highTempThreshold) {
                target = PowerProfile.Balanced;
                _highLoadTicks = 0;
                _cooldownTicks = 0;
            }
            // 2. High CPU load demand: boost to Performance
            else if (load >= props.highLoadThreshold) {
                _highLoadTicks++;
                if (_highLoadTicks >= 2 || load >= 0.75) {
                    target = PowerProfile.Performance;
                    _cooldownTicks = props.cooldownDuration;
                } else if (_cooldownTicks > 0) {
                    target = PowerProfile.Performance;
                } else {
                    target = PowerProfile.Balanced;
                }
            }
            // 3. Normal / low CPU load: keep in Balanced (or maintain Performance until cooldown expires)
            else {
                _highLoadTicks = 0;
                if (_cooldownTicks > 0) {
                    _cooldownTicks--;
                    target = PowerProfile.Performance;
                } else {
                    target = PowerProfile.Balanced;
                }
            }
        }

        if (PowerProfiles.profile !== target) {
            console.log(`[PowerManagement] Auto-balance: load=${Math.round(load * 100)}%, temp=${Math.round(temp)}°C -> switching profile from ${PowerProfiles.profile} to ${target}`);
            PowerProfiles.profile = target;
        }
    }

    Connections {
        target: Cpu
        function onPercentageChanged(): void {
            if (root.autoBalance)
                root.evaluate();
        }
        function onTemperatureChanged(): void {
            if (root.autoBalance)
                root.evaluate();
        }
    }

    Connections {
        target: UPower
        function onOnBatteryChanged(): void {
            if (root.autoBalance)
                root.evaluate();
        }
    }

    Connections {
        target: UPower.displayDevice
        function onPercentageChanged(): void {
            if (root.autoBalance)
                root.evaluate();
        }
    }

    Component.onCompleted: {
        if (root.autoBalance) {
            root.evaluate();
        }
    }

    IpcHandler {
        function isAuto(): bool {
            return root.autoBalance;
        }

        function toggleAuto(): void {
            root.toggleAutoBalance();
        }

        function enableAuto(): void {
            root.setAutoBalance(true);
        }

        function disableAuto(): void {
            root.setAutoBalance(false);
        }

        function getProfile(): string {
            if (root.autoBalance) {
                const load = Math.round(Cpu.percentage * 100);
                const temp = Math.round(Cpu.temperature);
                return `auto (${root.profileName.toLowerCase()}) [CPU: ${load}%, ${temp}°C]`;
            }
            return root.profileName.toLowerCase();
        }

        function setProfile(name: string): string {
            const lower = name.toLowerCase().trim();
            if (lower === "auto" || lower === "auto-balance" || lower === "autobalance") {
                root.setAutoBalance(true);
                return `Auto-balance enabled (profile: ${root.profileName})`;
            }
            if (lower === "saver" || lower === "powersaver" || lower === "power-saver" || lower === "save-power" || lower === "save_power") {
                root.setManualProfile(PowerProfile.PowerSaver);
                return "Power profile set to Power Saver";
            }
            if (lower === "balanced" || lower === "balance" || lower === "normal") {
                root.setManualProfile(PowerProfile.Balanced);
                return "Power profile set to Balanced";
            }
            if (lower === "perf" || lower === "performance" || lower === "hyper") {
                root.setManualProfile(PowerProfile.Performance);
                return "Power profile set to Performance";
            }
            return `Unknown profile: ${name}. Valid options: auto, save-power, normal, hyper`;
        }

        target: "power"
    }
}
