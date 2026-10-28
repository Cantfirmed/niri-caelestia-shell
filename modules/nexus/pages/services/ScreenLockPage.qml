import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    property int screenOffTimeout: 300
    property bool screenOffEnabled: true

    property int lockTimeout: 180
    property bool lockEnabled: true

    property int sleepTimeout: 600
    property bool sleepEnabled: true

    function matchesAction(itemAction, targetAction) {
        if (!itemAction || !targetAction)
            return false;
        let s = "";
        if (typeof itemAction === "string") {
            s = itemAction;
        } else if (itemAction.join) {
            s = itemAction.join(" ");
        } else if (itemAction.length !== undefined) {
            const arr = [];
            for (let i = 0; i < itemAction.length; i++) arr.push(itemAction[i]);
            s = arr.join(" ");
        } else {
            s = String(itemAction);
        }
        const targets = Array.isArray(targetAction) ? targetAction : [targetAction];
        for (let i = 0; i < targets.length; i++) {
            const t = targets[i];
            if (s === t || s.indexOf(t) !== -1)
                return true;
        }
        return false;
    }

    function findItem(targetAction) {
        const list = GlobalConfig.general.idle.timeouts;
        for (let i = 0; i < (list ? list.count : 0); i++) {
            const item = list.at(i);
            if (item && root.matchesAction(item.idleAction, targetAction))
                return item;
        }
        return null;
    }

    function ensureItem(targetAction, defaultTimeout, returnAction) {
        let item = root.findItem(targetAction);
        if (item)
            return item;
        const actionStr = Array.isArray(targetAction) ? targetAction[0] : targetAction;
        const props = {
            enabled: true,
            timeout: defaultTimeout,
            idleAction: actionStr
        };
        if (returnAction)
            props.returnAction = returnAction;
        return GlobalConfig.general.idle.timeouts.insert(props);
    }

    function setActionTimeout(targetAction, seconds, defaultTimeout, returnAction) {
        const item = root.ensureItem(targetAction, defaultTimeout, returnAction);
        if (item) {
            item.timeout = seconds;
        }
    }

    function setActionEnabled(targetAction, enabled, defaultTimeout, returnAction) {
        const item = root.ensureItem(targetAction, defaultTimeout, returnAction);
        if (item) {
            item.enabled = enabled;
        }
    }

    function loadFromConfig() {
        const list = GlobalConfig.general.idle.timeouts;
        for (let i = 0; i < (list ? list.count : 0); i++) {
            const item = list.at(i);
            if (!item)
                continue;
            if (root.matchesAction(item.idleAction, "dpms off")) {
                root.screenOffTimeout = item.timeout ?? 300;
                root.screenOffEnabled = item.enabled ?? true;
            } else if (root.matchesAction(item.idleAction, "lock")) {
                root.lockTimeout = item.timeout ?? 180;
                root.lockEnabled = item.enabled ?? true;
            } else if (root.matchesAction(item.idleAction, ["suspendThenHibernate", "suspend"])) {
                root.sleepTimeout = item.timeout ?? 600;
                root.sleepEnabled = item.enabled ?? true;
            }
        }
    }

    Component.onCompleted: loadFromConfig()

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0)
            return Tr.tr("Never");
        if (seconds < 60)
            return Tr.tr("%1 seconds").arg(seconds);
        const mins = Math.floor(seconds / 60);
        const remSecs = seconds % 60;
        if (remSecs === 0) {
            if (mins < 60)
                return mins === 1 ? Tr.tr("1 minute") : Tr.tr("%1 minutes").arg(mins);
            const hours = Math.floor(mins / 60);
            const remMins = mins % 60;
            if (remMins === 0)
                return hours === 1 ? Tr.tr("1 hour") : Tr.tr("%1 hours").arg(hours);
            return Tr.tr("%1h %2m").arg(hours).arg(remMins);
        }
        return Tr.tr("%1m %2s").arg(mins).arg(remSecs);
    }

    readonly property list<MenuItem> screenOffMenuItems: [
        MenuItem { text: Tr.tr("1 minute"); value: 60 },
        MenuItem { text: Tr.tr("2 minutes"); value: 120 },
        MenuItem { text: Tr.tr("3 minutes"); value: 180 },
        MenuItem { text: Tr.tr("5 minutes"); value: 300 },
        MenuItem { text: Tr.tr("10 minutes"); value: 600 },
        MenuItem { text: Tr.tr("15 minutes"); value: 900 },
        MenuItem { text: Tr.tr("20 minutes"); value: 1200 },
        MenuItem { text: Tr.tr("30 minutes"); value: 1800 },
        MenuItem { text: Tr.tr("1 hour"); value: 3600 },
        MenuItem { text: Tr.tr("2 hours"); value: 7200 },
        MenuItem { text: Tr.tr("Never"); value: 0 }
    ]

    readonly property list<MenuItem> lockMenuItems: [
        MenuItem { text: Tr.tr("1 minute"); value: 60 },
        MenuItem { text: Tr.tr("2 minutes"); value: 120 },
        MenuItem { text: Tr.tr("3 minutes"); value: 180 },
        MenuItem { text: Tr.tr("5 minutes"); value: 300 },
        MenuItem { text: Tr.tr("10 minutes"); value: 600 },
        MenuItem { text: Tr.tr("15 minutes"); value: 900 },
        MenuItem { text: Tr.tr("20 minutes"); value: 1200 },
        MenuItem { text: Tr.tr("30 minutes"); value: 1800 },
        MenuItem { text: Tr.tr("1 hour"); value: 3600 },
        MenuItem { text: Tr.tr("Never"); value: 0 }
    ]

    readonly property list<MenuItem> sleepMenuItems: [
        MenuItem { text: Tr.tr("5 minutes"); value: 300 },
        MenuItem { text: Tr.tr("10 minutes"); value: 600 },
        MenuItem { text: Tr.tr("15 minutes"); value: 900 },
        MenuItem { text: Tr.tr("20 minutes"); value: 1200 },
        MenuItem { text: Tr.tr("30 minutes"); value: 1800 },
        MenuItem { text: Tr.tr("1 hour"); value: 3600 },
        MenuItem { text: Tr.tr("2 hours"); value: 7200 },
        MenuItem { text: Tr.tr("Never"); value: 0 }
    ]

    title: Tr.tr("Screen & Lock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Connections {
            target: GlobalConfig.general.idle.timeouts
            function onElementsChanged() {
                root.loadFromConfig();
            }
            function onCountChanged() {
                root.loadFromConfig();
            }
        }

        // ---------------- Section 1: Screen Power Off ----------------
        SectionHeader {
            first: true
            text: Tr.tr("Screen Power")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Turn off screen when inactive")
            subtext: Tr.tr("Power off display monitors to save power when idle")
            checked: root.screenOffEnabled
            onToggled: {
                root.screenOffEnabled = checked;
                root.setActionEnabled("dpms off", checked, 300, "dpms on");
            }
        }

        SelectRow {
            label: Tr.tr("Turn off after")
            subtext: Tr.tr("Delay before display monitors power down")
            menuItems: root.screenOffMenuItems
            active: !root.screenOffEnabled ? root.screenOffMenuItems[root.screenOffMenuItems.length - 1] : (root.screenOffMenuItems.find(i => i.value === root.screenOffTimeout) ?? null)
            fallbackText: !root.screenOffEnabled ? Tr.tr("Never") : root.formatDuration(root.screenOffTimeout)
            enabled: root.screenOffEnabled
            onSelected: item => {
                if (item.value === 0) {
                    root.screenOffEnabled = false;
                    root.setActionEnabled("dpms off", false, 300, "dpms on");
                } else {
                    root.screenOffTimeout = item.value;
                    root.screenOffEnabled = true;
                    root.setActionTimeout("dpms off", item.value, 300, "dpms on");
                    root.setActionEnabled("dpms off", true, 300, "dpms on");
                }
            }
        }

        StepperRow {
            last: true
            label: Tr.tr("Fine-tune screen timeout")
            subtext: Tr.tr("Duration in minutes before screen powers off")
            value: Math.max(1, Math.round(root.screenOffTimeout / 60))
            from: 1
            to: 180
            stepSize: 1
            enabled: root.screenOffEnabled
            onMoved: v => {
                root.screenOffTimeout = Math.round(v * 60);
                root.screenOffEnabled = true;
                root.setActionTimeout("dpms off", root.screenOffTimeout, 300, "dpms on");
                root.setActionEnabled("dpms off", true, 300, "dpms on");
            }
        }

        // ---------------- Section 2: Auto-Lock ----------------
        SectionHeader {
            text: Tr.tr("Automatic Lock")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Automatically lock session")
            subtext: Tr.tr("Lock the screen after a period of inactivity")
            checked: root.lockEnabled
            onToggled: {
                root.lockEnabled = checked;
                root.setActionEnabled("lock", checked, 180, "");
            }
        }

        SelectRow {
            label: Tr.tr("Lock after")
            subtext: Tr.tr("Inactivity delay before locking the session")
            menuItems: root.lockMenuItems
            active: !root.lockEnabled ? root.lockMenuItems[root.lockMenuItems.length - 1] : (root.lockMenuItems.find(i => i.value === root.lockTimeout) ?? null)
            fallbackText: !root.lockEnabled ? Tr.tr("Never") : root.formatDuration(root.lockTimeout)
            enabled: root.lockEnabled
            onSelected: item => {
                if (item.value === 0) {
                    root.lockEnabled = false;
                    root.setActionEnabled("lock", false, 180, "");
                } else {
                    root.lockTimeout = item.value;
                    root.lockEnabled = true;
                    root.setActionTimeout("lock", item.value, 180, "");
                    root.setActionEnabled("lock", true, 180, "");
                }
            }
        }

        StepperRow {
            label: Tr.tr("Fine-tune lock timeout")
            subtext: Tr.tr("Duration in minutes before session locks")
            value: Math.max(1, Math.round(root.lockTimeout / 60))
            from: 1
            to: 180
            stepSize: 1
            enabled: root.lockEnabled
            onMoved: v => {
                root.lockTimeout = Math.round(v * 60);
                root.lockEnabled = true;
                root.setActionTimeout("lock", root.lockTimeout, 180, "");
                root.setActionEnabled("lock", true, 180, "");
            }
        }

        ToggleRow {
            last: true
            text: Tr.tr("Lock before sleep")
            subtext: Tr.tr("Lock the screen before the computer suspends or sleeps")
            checked: GlobalConfig.general.idle.lockBeforeSleep
            onToggled: GlobalConfig.general.idle.lockBeforeSleep = checked
        }

        // ---------------- Section 3: System Sleep ----------------
        SectionHeader {
            text: Tr.tr("System Sleep")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Automatic suspend")
            subtext: Tr.tr("Put computer into low-power sleep mode when idle")
            checked: root.sleepEnabled
            onToggled: {
                root.sleepEnabled = checked;
                root.setActionEnabled(["suspendThenHibernate", "suspend"], checked, 600, "");
            }
        }

        SelectRow {
            last: true
            label: Tr.tr("Sleep after")
            subtext: Tr.tr("Inactivity delay before entering suspend mode")
            menuItems: root.sleepMenuItems
            active: !root.sleepEnabled ? root.sleepMenuItems[root.sleepMenuItems.length - 1] : (root.sleepMenuItems.find(i => i.value === root.sleepTimeout) ?? null)
            fallbackText: !root.sleepEnabled ? Tr.tr("Never") : root.formatDuration(root.sleepTimeout)
            enabled: root.sleepEnabled
            onSelected: item => {
                if (item.value === 0) {
                    root.sleepEnabled = false;
                    root.setActionEnabled(["suspendThenHibernate", "suspend"], false, 600, "");
                } else {
                    root.sleepTimeout = item.value;
                    root.sleepEnabled = true;
                    root.setActionTimeout(["suspendThenHibernate", "suspend"], item.value, 600, "");
                    root.setActionEnabled(["suspendThenHibernate", "suspend"], true, 600, "");
                }
            }
        }

        // ---------------- Section 4: Exceptions ----------------
        SectionHeader {
            text: Tr.tr("Exceptions")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Inhibit when audio is playing")
            subtext: Tr.tr("Keep display awake and prevent auto-lock while media is playing")
            checked: GlobalConfig.general.idle.inhibitWhenAudio
            onToggled: GlobalConfig.general.idle.inhibitWhenAudio = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Inhibit when plugged in")
            subtext: Tr.tr("Prevent display sleep and auto-lock while connected to AC power")
            checked: GlobalConfig.general.idle.inhibitWhenCharging
            onToggled: GlobalConfig.general.idle.inhibitWhenCharging = checked
        }
    }
}
