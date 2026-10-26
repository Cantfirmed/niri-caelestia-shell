pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.services

Singleton {
    id: root

    property bool connected: false
    property string backendState: "NoState"
    property string ip: ""
    property string selfName: ""
    property string exitNode: ""
    property string lastError: ""

    property bool connectPending: false
    property bool disconnectPending: false
    readonly property bool connecting: connectProc.running || connectPending
    readonly property bool disconnecting: disconnectProc.running || disconnectPending

    function checkStatus(): void {
        if (!statusProc.running)
            statusProc.running = true;
    }

    function connect(): void {
        if (!connected && !connecting) {
            connectPending = true;
            connectProc.running = true;
        }
    }

    function disconnect(): void {
        if (connected && !disconnecting) {
            disconnectPending = true;
            disconnectProc.running = true;
        }
    }

    function toggle(): void {
        connected ? disconnect() : connect();
    }

    function extractAuthUrl(text: string): string {
        const m = text.match(/https?:\/\/[^\s"'<>]+/i);
        return m ? m[0] : "";
    }

    Process {
        id: statusProc

        command: ["tailscale", "status", "--json"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim().length === 0)
                    return;

                if (text.includes("Logged out") || text.includes("Stopped") || text.includes("not running") || text.includes("Tailscale is not running")) {
                    root.backendState = "Stopped";
                    root.connected = false;
                    root.ip = "";
                    root.exitNode = "";
                    return;
                }

                try {
                    const data = JSON.parse(text);
                    const backend = data.BackendState || "";
                    root.backendState = backend;
                    const isConn = (backend === "Running");
                    root.connected = isConn;
                    if (isConn) {
                        root.ip = (data.TailscaleIPs && data.TailscaleIPs.length > 0) ? data.TailscaleIPs[0] : "";
                        root.selfName = (data.Self && data.Self.HostName) ? data.Self.HostName : "";
                        let exit = "";
                        if (data.Peer) {
                            for (const key in data.Peer) {
                                const p = data.Peer[key];
                                if (p && p.ExitNode) {
                                    exit = (p.DNSName || p.HostName || "").replace(/\.$/, "");
                                    break;
                                }
                            }
                        }
                        root.exitNode = exit;
                    } else {
                        root.ip = "";
                        root.exitNode = "";
                    }
                } catch (e) {
                    // Ignore JSON parsing errors
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.includes("not running") || text.includes("Stopped")) {
                    root.backendState = "Stopped";
                    root.connected = false;
                    root.ip = "";
                    root.exitNode = "";
                }
            }
        }
    }

    Process {
        id: connectProc

        command: ["tailscale", "up"]

        onRunningChanged: {
            if (running) {
                root.connectPending = false;
                root.lastError = "";
            }
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            root.connectPending = false;
            Qt.callLater(() => {
                root.checkStatus();
                if (exitCode === 0) {
                    if (GlobalConfig.utilities.toasts?.vpnChanged ?? true) {
                        Toaster.toast(Tr.tr("Tailscale connected"), root.ip ? Tr.tr("Tailscale IP: %1").arg(root.ip) : Tr.tr("Connected to Tailscale network"), "hub");
                    }
                } else {
                    const reason = root.lastError.trim() || Tr.tr("Could not connect to Tailscale");
                    Toaster.toast(Tr.tr("Tailscale connection failed"), reason, "error");
                }
            });
        }

        stdout: SplitParser {
            onRead: data => {
                const authUrl = root.extractAuthUrl(data);
                if (authUrl) {
                    Toaster.toast(Tr.tr("Tailscale login required"), Tr.tr("Please complete authentication"), "open_in_browser");
                    Qt.openUrlExternally(authUrl);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.lastError = text;
                const authUrl = root.extractAuthUrl(text);
                if (authUrl) {
                    Toaster.toast(Tr.tr("Tailscale login required"), Tr.tr("Please complete authentication"), "open_in_browser");
                    Qt.openUrlExternally(authUrl);
                }
            }
        }
    }

    Process {
        id: disconnectProc

        command: ["tailscale", "down"]

        onRunningChanged: {
            if (running) {
                root.disconnectPending = false;
                root.lastError = "";
            }
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            root.disconnectPending = false;
            Qt.callLater(() => {
                root.checkStatus();
                if (exitCode === 0) {
                    if (GlobalConfig.utilities.toasts?.vpnChanged ?? true) {
                        Toaster.toast(Tr.tr("Tailscale disconnected"), Tr.tr("Disconnected from Tailscale network"), "hub");
                    }
                } else {
                    const reason = root.lastError.trim() || Tr.tr("Could not disconnect Tailscale");
                    Toaster.toast(Tr.tr("Tailscale error"), reason, "error");
                }
            });
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.lastError = text;
            }
        }
    }

    Timer {
        id: statusTimer

        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.checkStatus()
    }

    IpcHandler {
        target: "tailscale"

        function isConnected(): bool {
            return root.connected;
        }

        function toggle(): void {
            root.toggle();
        }

        function connect(): void {
            root.connect();
        }

        function disconnect(): void {
            root.disconnect();
        }

        function getStatus(): string {
            return root.backendState;
        }

        function getIp(): string {
            return root.ip;
        }
    }
}
