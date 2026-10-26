pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.I18n
import qs.services

Singleton {
    id: root

    /// Web servers running on user-owned listening ports.
    /// Items: { pid, comm, cmdline, cwd, project, ports[] }
    property var servers: []
    /// Docker containers, running first. Items: { id, name, image, state, status, ports, project }
    property var containers: []

    property bool dockerInstalled: true
    property bool dockerUp: true
    readonly property bool dockerAvailable: dockerInstalled && dockerUp

    /// container id -> "stop" | "restart" | "start" while an action is in flight
    property var busy: ({})
    /// pid key -> true while a kill is in flight
    property var killing: ({})

    /// Number of live consumers (the Dev tab attach/detach)
    property int refs: 0

    /// Scanned server rows from the current scan, grouped into `servers` on completion
    property var _serverRows: []
    /// Parsed container rows from the current docker scan, grouped into `containers` on completion
    property var _containers: []

    readonly property var serverKeywords: /(vite|webpack|react[- ]?scripts|ng serve|@?angular|next[- ]?(dev|start|serve)|next-?server|nextjs|nuxt|svelte|astro|gatsby|expo|parcel|snowpack|turbopack|esbuild|json-server|http-server|live-server|browser-sync|http\.server|uvicorn|gunicorn|runserver|flask|artisan serve|php -s|dotnet|rails|puma|spring-boot|caddy|serve$)/;

    /// Scans /proc for user-owned processes with a TCP listening socket.
    /// Emits: port|pid|comm|cmdline|cwd|project per line. `project` is 1 when the
    /// process cwd contains a known web project file (package.json, angular.json etc.).
    readonly property string serverScanScript: "ss -tlnpH 2>/dev/null | awk '"
            + `{
    port = $4
    u = index($0, "users:((")
    procs = ""
    if (u > 0) {
        e = index(substr($0, u), "))")
        if (e > 8)
            procs = substr($0, u + 8, e - 9)
    }
    if (port == "" || procs == "") next
    sub(/.*:/, "", port)
    seen = ""
    rest = procs
    while (match(rest, /pid=[0-9]+/)) {
        pid = substr(rest, RSTART + 4, RLENGTH - 4)
        if (index(" " seen " ", " " pid " ") == 0)
            seen = seen (seen == "" ? "" : " ") pid
        rest = substr(rest, RSTART + RLENGTH)
    }
    if (seen == "") next
    print port, seen
}' | while read -r port pids; do
    [ -n "$port" ] || continue
    for pid in $pids; do
        [ -r "/proc/$pid/comm" ] || continue
        comm=$(cat "/proc/$pid/comm" 2>/dev/null) || continue
        cmd=$(tr '\\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
        [ -n "$cmd" ] || cmd=$comm
        cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null)
        proj=""
        if [ -n "$cwd" ]; then
            for f in package.json angular.json vite.config.js vite.config.ts next.config.js nuxt.config.ts astro.config.js manage.py pyproject.toml; do
                [ -e "$cwd/$f" ] && proj=1 && break
            done
        fi
        printf '%s|%s|%s|%s|%s|%s\\n' "$port" "$pid" "$comm" "$cmd" "$cwd" "$proj"
    done
done`;

    function attach(): void {
        root.refs++;
        root.maybeRefresh();
    }

    function detach(): void {
        root.refs = Math.max(0, root.refs - 1);
    }

    function maybeRefresh(): void {
        if (root.refs > 0) {
            root.scanServers();
            root.checkContainers();
        }
    }

    function refresh(): void {
        root.scanServers();
        root.checkContainers();
    }

    /// Opens a local port in the default browser.
    function openServer(port: string): void {
        if (!port)
            return;
        Quickshell.execDetached(["xdg-open", `http://localhost:${port}`]);
    }

    /// Condenses docker's `-p` output into a short ":3000, :8080" list.
    function formatPorts(ports: string): string {
        if (!ports)
            return "";
        const unique = [];
        for (const entry of ports.split(",")) {
            const part = entry.trim();
            if (!part)
                continue;
            const host = part.split("->")[0].split("/")[0];
            const seg = host.split(":").pop();
            if (seg && seg.length > 0 && !unique.includes(seg))
                unique.push(seg);
        }
        return unique.map(p => ":" + p).join(", ");
    }

    function scanServers(): void {
        if (!serversProc.running)
            serversProc.running = true;
    }

    function checkContainers(): void {
        if (!dockerProc.running)
            dockerProc.running = true;
    }

    function stopContainer(id: string): void {
        root.dockerAction("stop", id);
    }

    function restartContainer(id: string): void {
        root.dockerAction("restart", id);
    }

    function startContainer(id: string): void {
        root.dockerAction("start", id);
    }

    function dockerAction(verb: string, id: string): void {
        if (root.busy[id])
            return;
        const busy = Object.assign({}, root.busy);
        busy[id] = verb;
        root.busy = busy;
        dockerActionProc.userData = verb + ":" + id;
        dockerActionProc.command = ["docker", verb, id];
        dockerActionProc.running = true;
    }

    function stopServer(pids: list<string>): void {
        const key = pids.join(",");
        if (root.killing[key])
            return;
        const killing = Object.assign({}, root.killing);
        killing[key] = true;
        root.killing = killing;
        killProc.userData = key;
        killProc.command = ["kill", "--", ...pids];
        killProc.running = true;
    }

    // Helpers ---------------------------------------------------------------

    function composeProject(labels: string): string {
        const m = labels.match(/com\.docker\.compose\.project=([^,]*)/);
        return m ? m[1] : "";
    }

    function containerName(id: string): string {
        const c = containers.find(c => c.id === id);
        return c ? c.name : id;
    }

    // Polling -----------------------------------------------------------------

    Timer {
        id: serverTimer

        interval: 4000
        repeat: true
        running: root.refs > 0
        triggeredOnStart: true
        onTriggered: root.scanServers()
    }

    Timer {
        id: dockerTimer

        interval: 4000
        repeat: true
        running: root.refs > 0
        triggeredOnStart: true
        onTriggered: root.checkContainers()
    }

    // Web servers -------------------------------------------------------------

    Process {
        id: serversProc

        command: ["sh", "-c", root.serverScanScript]

        onRunningChanged: {
            if (running)
                root._serverRows = [];
        }

        stdout: SplitParser {
            onRead: data => {
                const parts = data.split("|");
                if (parts.length < 6)
                    return;
                const proj = parts.pop();
                const cwd = parts.pop();
                const port = parts[0];
                const pid = parts[1];
                const comm = parts[2];
                const cmd = parts.slice(3).join("|").trim();
                root._serverRows.push({
                    port,
                    pid,
                    comm,
                    cmdline: cmd,
                    cwd,
                    project: proj === "1"
                });
            }
        }

        onExited: {
            const byPid = {};
            for (const row of root._serverRows) {
                const entry = byPid[row.pid];
                if (entry) {
                    if (!entry.ports.includes(row.port))
                        entry.ports.push(row.port);
                } else {
                    byPid[row.pid] = {
                        pid: row.pid,
                        comm: row.comm,
                        cmdline: row.cmdline,
                        cwd: row.cwd,
                        project: row.project,
                        ports: [row.port]
                    };
                }
            }

            const servers = [];
            for (const pid in byPid) {
                const s = byPid[pid];
                const hay = (s.cmdline + " " + s.comm).toLowerCase();
                const isRuntime = /^(node|nodejs|npm|yarn|pnpm|bun|deno|python[0-9.]*|php|ruby|go|cargo|dotnet)$/.test(s.comm);
                if (root.serverKeywords.test(hay) || (s.project && isRuntime))
                    servers.push(s);
            }
            servers.sort((a, b) => a.ports[0] - b.ports[0]);
            root.servers = servers;
        }
    }

    Process {
        id: killProc

        property string userData: ""
        property string lastErr: ""

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            const key = killProc.userData;
            const killing = Object.assign({}, root.killing);
            delete killing[key];
            root.killing = killing;

            if (exitCode === 0)
                Toaster.toast(Tr.tr("Server stopped"), Tr.tr("Development server was killed"), "code");
            else
                Toaster.toast(Tr.tr("Failed to stop server"), killProc.lastErr.trim() || Tr.tr("Could not kill the process"), "error");

            // Refresh quickly to drop the killed row
            delayedRescan.restart();
        }

        stderr: SplitParser {
            onRead: data => killProc.lastErr = data
        }
    }

    // Docker containers ---------------------------------------------------------

    Process {
        id: dockerProc

        property string lastErr: ""

        command: ["docker", "ps", "-a", "--format", "{{json .}}"]

        onRunningChanged: {
            if (running)
                root._containers = [];
        }

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line)
                    return;
                try {
                    const d = JSON.parse(line);
                    root._containers.push({
                        id: d.ID ?? "",
                        name: d.Names ?? "",
                        image: d.Image ?? "",
                        state: d.State ?? "",
                        status: d.Status ?? "",
                        ports: d.Ports ?? "",
                        project: root.composeProject(d.Labels ?? "")
                    });
                } catch (e) {
                    // Ignore malformed lines
                }
            }
        }

        stderr: SplitParser {
            onRead: data => dockerProc.lastErr = data
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (exitCode === 127) {
                root.dockerInstalled = false;
                root.dockerUp = false;
                root.containers = [];
                return;
            }

            if (exitCode !== 0) {
                const wasUp = root.dockerUp;
                root.dockerUp = false;
                root.containers = [];
                // Only warn on the transition so the 4s poll does not spam toasts
                if (root.refs > 0 && wasUp)
                    Toaster.toast(Tr.tr("Docker unreachable"), dockerProc.lastErr.trim() || Tr.tr("Is the Docker daemon running?"), "error");
                return;
            }

            root.dockerInstalled = true;
            root.dockerUp = true;

            const running = [];
            const stopped = [];
            for (const c of root._containers) {
                if (c.state === "running")
                    running.push(c);
                else
                    stopped.push(c);
            }
            running.sort((a, b) => a.name.localeCompare(b.name));
            stopped.sort((a, b) => a.name.localeCompare(b.name));
            root.containers = [...running, ...stopped];
        }
    }

    Process {
        id: dockerActionProc

        property string userData: ""
        property string lastErr: ""

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            const sep = dockerActionProc.userData.indexOf(":");
            const verb = dockerActionProc.userData.slice(0, sep);
            const id = dockerActionProc.userData.slice(sep + 1);

            const busy = Object.assign({}, root.busy);
            delete busy[id];
            root.busy = busy;

            if (exitCode === 0) {
                const titles = {
                    stop: Tr.tr("Container stopped"),
                    restart: Tr.tr("Container restarted"),
                    start: Tr.tr("Container started")
                };
                Toaster.toast(titles[verb] ?? Tr.tr("Container updated"), root.containerName(id), "deployed_code");
            } else {
                Toaster.toast(Tr.tr("Docker action failed"), dockerActionProc.lastErr.trim() || Tr.tr("Could not run docker %1").arg(verb), "error");
            }

            // Refresh quickly so state stays accurate
            delayedDockerCheck.restart();
        }

        stderr: SplitParser {
            onRead: data => dockerActionProc.lastErr = data
        }
    }

    // Rapid follow-up refreshes after actions (full state settles just after)
    Timer {
        id: delayedRescan

        interval: 1500
        onTriggered: root.scanServers()
    }

    Timer {
        id: delayedDockerCheck

        interval: 1500
        onTriggered: root.checkContainers()
    }
}
