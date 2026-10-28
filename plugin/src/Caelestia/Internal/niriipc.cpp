#include "niriipc.hpp"

#include <qdebug.h>
#include <qdir.h>
#include <qfile.h>
#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qjsonvalue.h>

#include <algorithm>
#include <utility>

namespace caelestia {

// ── NiriListModel ────────────────────────────────────────────────────────────

NiriListModel::NiriListModel(QObject* parent) : QAbstractListModel(parent) {}

QHash<int, QByteArray> NiriListModel::roleNames() const {
    return { {ObjectRole, QByteArrayLiteral("modelData")} };
}

int NiriListModel::rowCount(const QModelIndex& parent) const {
    Q_UNUSED(parent);
    return static_cast<int>(m_items.size());
}

QVariant NiriListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_items.size() || index.row() < 0) return {};
    if (role == ObjectRole) return m_items.at(index.row());
    return {};
}

void NiriListModel::resetData(const QVariantList& items) {
    beginResetModel();
    m_items = items;
    endResetModel();
}

void NiriListModel::appendItem(const QVariantMap& item) {
    const int pos = static_cast<int>(m_items.size());
    beginInsertRows(QModelIndex(), pos, pos);
    m_items.append(item);
    endInsertRows();
}

void NiriListModel::setItem(int idx, const QVariantMap& item) {
    if (idx < 0 || idx >= m_items.size()) return;
    m_items[idx] = item;
    emit dataChanged(index(idx), index(idx), {ObjectRole});
}

void NiriListModel::updateItemSilent(int idx, const QVariantMap& item) {
    if (idx < 0 || idx >= m_items.size()) return;
    m_items[idx] = item;
}

void NiriListModel::removeItem(int idx) {
    if (idx < 0 || idx >= m_items.size()) return;
    beginRemoveRows(QModelIndex(), idx, idx);
    m_items.removeAt(idx);
    endRemoveRows();
}

const QVariantList& NiriListModel::items() const {
    return m_items;
}

// ── NiriIpc ──────────────────────────────────────────────────────────────────

NiriIpc::NiriIpc(QObject* parent)
    : QObject(parent)
    , m_eventSocket(this)
    , m_requestSocket(this) {

    m_workspacesModel = new NiriListModel(this);
    m_windowsModel = new NiriListModel(this);

    m_viewportThrottleTimer.setSingleShot(true);
    m_viewportThrottleTimer.setInterval(30);
    connect(&m_viewportThrottleTimer, &QTimer::timeout, this, &NiriIpc::viewportChanged);

    connect(&m_eventSocket, &NiriEventSocket::connected, this, &NiriIpc::onEventStreamConnected);
    connect(&m_eventSocket, &NiriEventSocket::disconnected, this, &NiriIpc::onEventStreamDisconnected);
    connect(&m_eventSocket, &NiriEventSocket::eventReceived, this, &NiriIpc::onEvent);

    setupLedWatchers();
    m_eventSocket.connectToNiri();
}

// ── Property getters ─────────────────────────────────────────────────────────

bool NiriIpc::available() const { return m_available; }

QAbstractListModel* NiriIpc::workspacesModel() const { return m_workspacesModel; }
QVariantList NiriIpc::workspaces() const { return m_workspacesModel->items(); }
int NiriIpc::focusedWorkspaceIndex() const { return m_focusedWorkspaceIndex; }
int NiriIpc::focusedWorkspaceId() const { return m_focusedWorkspaceId; }
QString NiriIpc::focusedMonitorName() const { return m_focusedMonitorName; }
QVariantList NiriIpc::currentOutputWorkspaces() const { return m_currentOutputWorkspaces; }
QVariantMap NiriIpc::workspaceHasWindows() const { return m_workspaceHasWindows; }

QAbstractListModel* NiriIpc::windowsModel() const { return m_windowsModel; }
QVariantList NiriIpc::windows() const { return m_windowsModel->items(); }
int NiriIpc::focusedWindowIndex() const { return m_focusedWindowIndex; }
QString NiriIpc::focusedWindowId() const { return m_focusedWindowId; }
QString NiriIpc::focusedWindowTitle() const { return m_focusedWindowTitle; }
QString NiriIpc::focusedWindowClass() const { return m_focusedWindowClass; }
QVariantMap NiriIpc::focusedWindow() const { return m_focusedWindow; }
QVariantMap NiriIpc::lastFocusedWindow() const { return m_lastFocusedWindow; }
QString NiriIpc::scrollDirection() const { return m_scrollDirection; }
bool NiriIpc::inOverview() const { return m_inOverview; }

QVariantMap NiriIpc::outputs() const { return m_outputs; }

QVariantList NiriIpc::kbLayoutsArray() const { return m_kbLayoutsArray; }
int NiriIpc::kbLayoutIndex() const { return m_kbLayoutIndex; }
QString NiriIpc::kbLayouts() const { return m_kbLayouts; }

QString NiriIpc::defaultKbLayout() const {
    if (!m_kbLayoutsArray.isEmpty()) {
        return m_kbLayoutsArray.first().toString();
    }
    return QStringLiteral("?");
}

QString NiriIpc::kbLayout() const {
    if (m_kbLayoutIndex >= 0 && m_kbLayoutIndex < m_kbLayoutsArray.size()) {
        const QString name = m_kbLayoutsArray.at(m_kbLayoutIndex).toString();
        if (name.size() >= 2) {
            return name.left(2).toLower();
        }
    }
    return QStringLiteral("?");
}

bool NiriIpc::capsLock() const { return m_capsLock; }
bool NiriIpc::numLock() const { return m_numLock; }

// ── Actions & Atomic Column Move Transactions ────────────────────────────────

QByteArray NiriIpc::buildFocusWindowPayload(qint64 windowId) {
    QJsonObject inner;
    inner[QStringLiteral("id")] = windowId;
    QJsonObject actionObj;
    actionObj[QStringLiteral("FocusWindow")] = inner;
    QJsonObject wrapper;
    wrapper[QStringLiteral("Action")] = actionObj;
    return QJsonDocument(wrapper).toJson(QJsonDocument::Compact);
}

QByteArray NiriIpc::buildMoveColumnPayload(int targetIndex) {
    QJsonObject inner;
    inner[QStringLiteral("index")] = targetIndex;
    QJsonObject actionObj;
    actionObj[QStringLiteral("MoveColumnToIndex")] = inner;
    QJsonObject wrapper;
    wrapper[QStringLiteral("Action")] = actionObj;
    return QJsonDocument(wrapper).toJson(QJsonDocument::Compact);
}

bool NiriIpc::moveColumnToIndex(qint64 windowId, int targetIndex, bool restoreFocus) {
    if (!m_available || windowId <= 0 || targetIndex < 1) {
        return false;
    }
    if (findWindowIndexById(windowId) < 0) {
        qWarning() << "NiriIpc::moveColumnToIndex: target window does not exist:" << windowId;
        emit columnMoveCompleted(windowId, false);
        return false;
    }

    const qint64 origFocus = m_focusedWindowId.isEmpty() ? -1 : m_focusedWindowId.toLongLong();

    ColumnMoveTransaction tx;
    tx.steps.append(ColumnMoveStep{windowId, targetIndex, false});
    tx.originalFocusWindowId = origFocus;
    tx.primaryWindowId = windowId;
    tx.restoreFocus = restoreFocus;
    enqueueMoveTransaction(std::move(tx));
    return true;
}

bool NiriIpc::reorderColumn(qint64 windowId, int targetIndex) {
    return moveColumnToIndex(windowId, targetIndex, true);
}

bool NiriIpc::moveGroupColumns(
    const QVariantList& windowIds,
    const QVariantList& targetIndices,
    qint64 restoreFocusWindowId
) {
    if (!m_available || windowIds.isEmpty()) {
        return false;
    }

    ColumnMoveTransaction tx;
    const int fallbackIdx = targetIndices.isEmpty() ? 1 : qMax(1, targetIndices.first().toInt());

    for (int i = 0; i < windowIds.size(); ++i) {
        const qint64 wid = windowIds.at(i).toLongLong();
        if (wid <= 0 || findWindowIndexById(wid) < 0) {
            continue;
        }
        const int tIdx = (i < targetIndices.size())
            ? qMax(1, targetIndices.at(i).toInt())
            : fallbackIdx;
        tx.steps.append(ColumnMoveStep{wid, tIdx, false});
    }

    if (tx.steps.isEmpty()) {
        return false;
    }

    const qint64 currentFocus = m_focusedWindowId.isEmpty() ? -1 : m_focusedWindowId.toLongLong();
    tx.originalFocusWindowId = (restoreFocusWindowId > 0) ? restoreFocusWindowId : currentFocus;
    tx.primaryWindowId = tx.steps.first().windowId;
    tx.restoreFocus = true;
    enqueueMoveTransaction(std::move(tx));
    return true;
}

void NiriIpc::enqueueMoveTransaction(ColumnMoveTransaction tx) {
    m_moveQueue.push_back(std::move(tx));
    if (!m_moveInFlight) {
        processNextMoveTransaction();
    }
}

void NiriIpc::processNextMoveTransaction() {
    if (m_moveInFlight || m_moveQueue.empty()) {
        return;
    }

    m_activeMoveTx = std::move(m_moveQueue.front());
    m_moveQueue.pop_front();
    m_moveInFlight = true;
    executeNextMoveStep();
}

void NiriIpc::executeNextMoveStep() {
    if (!m_moveInFlight) {
        return;
    }

    while (m_activeMoveTx.currentStep < m_activeMoveTx.steps.size()) {
        const auto& step = m_activeMoveTx.steps.at(m_activeMoveTx.currentStep);
        if (!step.cancelled && step.windowId > 0 && findWindowIndexById(step.windowId) >= 0) {
            break;
        }
        ++m_activeMoveTx.currentStep;
    }

    if (m_activeMoveTx.currentStep >= m_activeMoveTx.steps.size()) {
        finishActiveMoveTransaction();
        return;
    }

    const int stepIdx = m_activeMoveTx.currentStep;
    const qint64 targetWinId = m_activeMoveTx.steps.at(stepIdx).windowId;
    const int targetColIdx = m_activeMoveTx.steps.at(stepIdx).targetIndex;

    // Step 1: Send FocusWindow and wait for compositor socket confirmation
    m_requestSocket.request(buildFocusWindowPayload(targetWinId), [this, stepIdx, targetWinId, targetColIdx](bool focusOk, const QJsonObject&) {
        if (!m_moveInFlight || stepIdx != m_activeMoveTx.currentStep) {
            return;
        }

        // Guard against target window closing mid-transaction before dispatching MoveColumnToIndex
        const bool stillAlive = !m_activeMoveTx.steps.at(stepIdx).cancelled && findWindowIndexById(targetWinId) >= 0;
        if (!focusOk || !stillAlive) {
            qWarning() << "NiriIpc: Aborting column move step; window closed or FocusWindow failed:" << targetWinId;
            ++m_activeMoveTx.currentStep;
            executeNextMoveStep();
            return;
        }

        // Step 2: Immediately dispatch MoveColumnToIndex on socket confirmation
        m_requestSocket.request(buildMoveColumnPayload(targetColIdx), [this, stepIdx, targetWinId](bool moveOk, const QJsonObject&) {
            if (!m_moveInFlight || stepIdx != m_activeMoveTx.currentStep) {
                return;
            }
            if (moveOk) {
                m_activeMoveTx.anyMoved = true;
                m_activeMoveTx.lastMovedWindowId = targetWinId;
            }
            ++m_activeMoveTx.currentStep;
            executeNextMoveStep();
        });
    });
}

void NiriIpc::finishActiveMoveTransaction() {
    if (!m_moveInFlight) {
        return;
    }

    const qint64 origFocus = m_activeMoveTx.originalFocusWindowId;
    const bool needRestore = m_activeMoveTx.restoreFocus
        && origFocus > 0
        && origFocus != m_activeMoveTx.lastMovedWindowId
        && findWindowIndexById(origFocus) >= 0;

    const qint64 primaryId = m_activeMoveTx.primaryWindowId;
    const bool success = m_activeMoveTx.anyMoved;
    auto cb = std::move(m_activeMoveTx.callback);

    auto completeTx = [this, primaryId, success, cb = std::move(cb)]() {
        m_activeMoveTx = {};
        m_moveInFlight = false;
        if (cb) {
            cb(success);
        }
        emit columnMoveCompleted(primaryId, success);
        processNextMoveTransaction();
    };

    if (needRestore) {
        // Step 3: Immediately restore original focus on socket confirmation
        m_requestSocket.request(buildFocusWindowPayload(origFocus), [completeTx = std::move(completeTx)](bool, const QJsonObject&) mutable {
            completeTx();
        });
    } else {
        completeTx();
    }
}

void NiriIpc::invalidateClosedWindowInTransactions(qint64 closedId) {
    if (m_moveInFlight) {
        for (auto& step : m_activeMoveTx.steps) {
            if (step.windowId == closedId) {
                step.cancelled = true;
            }
        }
        if (m_activeMoveTx.originalFocusWindowId == closedId) {
            m_activeMoveTx.originalFocusWindowId = -1;
        }
    }

    for (auto& tx : m_moveQueue) {
        for (auto& step : tx.steps) {
            if (step.windowId == closedId) {
                step.cancelled = true;
            }
        }
        if (tx.originalFocusWindowId == closedId) {
            tx.originalFocusWindowId = -1;
        }
    }
}

bool NiriIpc::action(const QString& actionName, const QVariantList& args) {
    if (!m_available) return false;

    // Convert action name from kebab-case to PascalCase for IPC
    QString pascalName;
    bool capitalizeNext = true;
    for (const QChar& c : actionName) {
        if (c == QLatin1Char('-')) {
            capitalizeNext = true;
        } else {
            pascalName += capitalizeNext ? c.toUpper() : c;
            capitalizeNext = false;
        }
    }

    QJsonObject actionObj;
    QJsonValue innerValue;

    if (args.size() >= 2 && args.at(0).toString() == QStringLiteral("--id")) {
        const qint64 id = args.at(1).toLongLong();
        if (pascalName == QStringLiteral("FocusWorkspace")) {
            QJsonObject ref;
            ref[QStringLiteral("Id")] = id;
            QJsonObject inner;
            inner[QStringLiteral("reference")] = ref;
            innerValue = inner;
        } else {
            QJsonObject inner;
            inner[QStringLiteral("id")] = id;
            innerValue = inner;
        }
    } else if (args.size() == 2 && args.at(0).toString() == QStringLiteral("-d")) {
        QJsonObject inner;
        inner[QStringLiteral("delay_ms")] = args.at(1).toInt();
        innerValue = inner;
    } else if (args.isEmpty()) {
        if (pascalName == QStringLiteral("ScreenshotWindow")) {
            QJsonObject inner;
            inner[QStringLiteral("id")] = QJsonValue::Null;
            inner[QStringLiteral("write_to_disk")] = true;
            inner[QStringLiteral("path")] = QJsonValue::Null;
            innerValue = inner;
        } else if (pascalName == QStringLiteral("CloseWindow") ||
                   pascalName == QStringLiteral("ToggleWindowFloating")) {
            QJsonObject inner;
            inner[QStringLiteral("id")] = QJsonValue::Null;
            innerValue = inner;
        } else {
            innerValue = QJsonObject();
        }
    } else if (args.size() == 1) {
        bool isNumber = false;
        const qint64 num = args.at(0).toLongLong(&isNumber);

        if (pascalName == QStringLiteral("FocusWorkspace")) {
            QJsonObject ref;
            ref[QStringLiteral("Index")] = num;
            QJsonObject inner;
            inner[QStringLiteral("reference")] = ref;
            innerValue = inner;
        } else if (pascalName == QStringLiteral("MoveWindowToWorkspace")) {
            QJsonObject ref;
            ref[QStringLiteral("Index")] = num;
            QJsonObject inner;
            inner[QStringLiteral("window_id")] = QJsonValue::Null;
            inner[QStringLiteral("reference")] = ref;
            inner[QStringLiteral("focus")] = true;
            innerValue = inner;
        } else if (pascalName == QStringLiteral("MoveColumnToIndex") ||
                   pascalName == QStringLiteral("FocusColumn")) {
            QJsonObject inner;
            inner[QStringLiteral("index")] = num;
            innerValue = inner;
        } else if (isNumber) {
            QJsonObject inner;
            inner[QStringLiteral("id")] = num;
            innerValue = inner;
        } else {
            innerValue = args.at(0).toString();
        }
    } else {
        qWarning() << "NiriIpc: Unhandled action args for" << actionName << args;
        innerValue = QJsonObject();
    }

    actionObj[pascalName] = innerValue;

    QJsonObject wrapper;
    wrapper[QStringLiteral("Action")] = actionObj;
    const QByteArray payload = QJsonDocument(wrapper).toJson(QJsonDocument::Compact);

    m_requestSocket.action(payload);
    return true;
}

int NiriIpc::getWorkspaceIdxById(int workspaceId) const {
    const auto& wsList = m_workspacesModel->items();
    for (const auto& v : wsList) {
        const auto ws = v.toMap();
        if (ws.value(QStringLiteral("id")).toInt() == workspaceId) {
            return ws.value(QStringLiteral("idx")).toInt();
        }
    }
    return -1;
}

QVariantList NiriIpc::getWindowsByWorkspaceId(int wsId) const {
    QVariantList res;
    const auto& wins = m_windowsModel->items();
    for (const auto& w : wins) {
        auto map = w.toMap();
        if (map.value(QStringLiteral("workspace_id")).toInt() == wsId) {
            res.append(w);
        }
    }
    return res;
}

QVariantList NiriIpc::getWindowsByWorkspaceIndex(int index) const {
    const auto& wsList = m_workspacesModel->items();
    if (index < 0 || index >= wsList.size()) return {};
    const int wsId = wsList.at(index).toMap().value(QStringLiteral("id")).toInt();
    return getWindowsByWorkspaceId(wsId);
}

QVariantList NiriIpc::getWorkspacesForOutput(const QString& outputName) const {
    QVariantList result;
    const auto& wsList = m_workspacesModel->items();
    for (const auto& v : wsList) {
        if (v.toMap().value(QStringLiteral("output")).toString() == outputName) {
            result.append(v);
        }
    }
    return result;
}

QVariantList NiriIpc::getActiveWorkspaceWindows() const {
    if (m_focusedWorkspaceId < 0) return {};
    return getWindowsByWorkspaceId(m_focusedWorkspaceId);
}

// ── Event Stream Slots ───────────────────────────────────────────────────────

void NiriIpc::onEventStreamConnected() {
    qDebug() << "NiriIpc: Event stream connected";
    m_available = true;
    emit availableChanged();
    fetchInitialState();
}

void NiriIpc::onEventStreamDisconnected() {
    qDebug() << "NiriIpc: Event stream disconnected";
    m_available = false;
    emit availableChanged();
}

void NiriIpc::onEvent(const QJsonObject& event) {
    if (event.contains(QStringLiteral("WorkspacesChanged"))) {
        handleWorkspacesChanged(event.value(QStringLiteral("WorkspacesChanged")).toObject());
    } else if (event.contains(QStringLiteral("WorkspaceActivated"))) {
        const auto data = event.value(QStringLiteral("WorkspaceActivated")).toObject();
        const int id = data.value(QStringLiteral("id")).toInt();
        const bool focused = data.value(QStringLiteral("focused")).toBool();
        if (focused) {
            m_focusedWorkspaceId = id;
        }

        QVariantList currentWs = m_workspacesModel->items();
        bool found = false;
        for (int i = 0; i < currentWs.size(); ++i) {
            auto ws = currentWs.at(i).toMap();
            if (ws.value(QStringLiteral("id")).toInt() == id) {
                found = true;
                if (focused) {
                    m_focusedWorkspaceIndex = i;
                    m_focusedMonitorName = ws.value(QStringLiteral("output")).toString();
                }
                const QString output = ws.value(QStringLiteral("output")).toString();
                for (int j = 0; j < currentWs.size(); ++j) {
                    auto w = currentWs.at(j).toMap();
                    if (w.value(QStringLiteral("output")).toString() == output) {
                        w[QStringLiteral("is_active")] = (j == i);
                        w[QStringLiteral("is_focused")] = focused && (j == i);
                        currentWs[j] = w;
                        m_workspacesModel->setItem(j, w);
                    } else if (focused && w.value(QStringLiteral("is_focused")).toBool()) {
                        w[QStringLiteral("is_focused")] = false;
                        currentWs[j] = w;
                        m_workspacesModel->setItem(j, w);
                    }
                }
                break;
            }
        }
        if (!found) {
            m_requestSocket.request(QByteArrayLiteral("\"Workspaces\""), [this](bool ok, const QJsonObject& resp) {
                if (!ok) return;
                const auto result = resp.value(QStringLiteral("result")).toObject();
                QJsonObject d;
                d[QStringLiteral("workspaces")] = result.value(QStringLiteral("Workspaces"));
                handleWorkspacesChanged(d);
            });
        }
        updateCurrentOutputWorkspaces();
        emit workspaceActivated(id, focused);
        emit workspacesChanged();
        emit focusedWorkspaceChanged();
    } else if (event.contains(QStringLiteral("WindowsChanged"))) {
        handleWindowsChanged(event.value(QStringLiteral("WindowsChanged")).toObject());
    } else if (event.contains(QStringLiteral("WindowOpenedOrChanged"))) {
        handleWindowOpenedOrChanged(event.value(QStringLiteral("WindowOpenedOrChanged")).toObject());
    } else if (event.contains(QStringLiteral("WindowClosed"))) {
        handleWindowClosed(event.value(QStringLiteral("WindowClosed")).toObject());
    } else if (event.contains(QStringLiteral("WindowFocusChanged"))) {
        handleWindowFocusChanged(event.value(QStringLiteral("WindowFocusChanged")).toObject());
    } else if (event.contains(QStringLiteral("WindowLayoutsChanged"))) {
        handleWindowLayoutsChanged(event.value(QStringLiteral("WindowLayoutsChanged")).toObject());
    } else if (event.contains(QStringLiteral("KeyboardLayoutsChanged"))) {
        handleKeyboardLayoutsChanged(event.value(QStringLiteral("KeyboardLayoutsChanged")).toObject());
    } else if (event.contains(QStringLiteral("OverviewOpenedOrClosed"))) {
        handleOverviewOpenedOrClosed(event.value(QStringLiteral("OverviewOpenedOrClosed")).toObject());
    } else if (event.contains(QStringLiteral("OutputsChanged"))) {
        handleOutputsChanged(event.value(QStringLiteral("OutputsChanged")).toObject());
    } else if (event.contains(QStringLiteral("ConfigLoaded"))) {
        qDebug() << "NiriIpc: ConfigLoaded event received";
        fetchOutputs();
    }
}

// ── Initial State ────────────────────────────────────────────────────────────

void NiriIpc::fetchInitialState() {
    m_requestSocket.request(QByteArrayLiteral("\"Workspaces\""), [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        QJsonObject data;
        data[QStringLiteral("workspaces")] = result.value(QStringLiteral("Workspaces"));
        handleWorkspacesChanged(data);
    });

    m_requestSocket.request(QByteArrayLiteral("\"Windows\""), [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        QJsonObject data;
        data[QStringLiteral("windows")] = result.value(QStringLiteral("Windows"));
        handleWindowsChanged(data);
    });

    m_requestSocket.request(QByteArrayLiteral("\"FocusedWindow\""), [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        const auto win = result.value(QStringLiteral("FocusedWindow"));
        if (win.isObject()) {
            QJsonObject d;
            d[QStringLiteral("id")] = win.toObject().value(QStringLiteral("id"));
            handleWindowFocusChanged(d);
        }
    });

    fetchOutputs();

    m_requestSocket.request(QByteArrayLiteral("\"KeyboardLayouts\""), [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        QJsonObject data;
        data[QStringLiteral("keyboard_layouts")] = result.value(QStringLiteral("KeyboardLayouts"));
        handleKeyboardLayoutsChanged(data);
    });
}

void NiriIpc::fetchOutputs() {
    m_requestSocket.request(QByteArrayLiteral("\"Outputs\""), [this](bool ok, const QJsonObject& resp) {
        if (!ok) {
            return;
        }
        const auto result = resp.value(QStringLiteral("result")).toObject();
        const auto outputs = result.value(QStringLiteral("Outputs")).toObject();
        m_outputs = outputs.toVariantMap();
        emit outputsChanged();
    });
}

// ── Event Handlers ───────────────────────────────────────────────────────────

static QVariantMap jsonObjectToVariantMap(const QJsonObject& obj) {
    return obj.toVariantMap();
}

static QVariantList jsonArrayToVariantList(const QJsonArray& arr) {
    return arr.toVariantList();
}

void NiriIpc::handleWorkspacesChanged(const QJsonObject& data) {
    const QJsonArray wsArray = data.value(QStringLiteral("workspaces")).toArray();

    QVariantList wsList = jsonArrayToVariantList(wsArray);

    std::sort(wsList.begin(), wsList.end(), [](const QVariant& a, const QVariant& b) {
        const auto mapA = a.toMap();
        const auto mapB = b.toMap();
        const QString outA = mapA.value(QStringLiteral("output")).toString();
        const QString outB = mapB.value(QStringLiteral("output")).toString();
        if (outA != outB) return outA < outB;
        return mapA.value(QStringLiteral("idx")).toInt()
             < mapB.value(QStringLiteral("idx")).toInt();
    });

    m_workspacesModel->resetData(wsList);

    m_focusedWorkspaceIndex = -1;
    m_focusedWorkspaceId = -1;
    for (int i = 0; i < wsList.size(); ++i) {
        const auto ws = wsList.at(i).toMap();
        if (ws.value(QStringLiteral("is_focused")).toBool()) {
            m_focusedWorkspaceIndex = i;
            m_focusedWorkspaceId = ws.value(QStringLiteral("id")).toInt();
            m_focusedMonitorName = ws.value(QStringLiteral("output")).toString();
            break;
        }
    }

    if (m_focusedWorkspaceIndex < 0 && !wsList.isEmpty()) {
        m_focusedWorkspaceIndex = 0;
    }

    updateCurrentOutputWorkspaces();
    updateWorkspaceHasWindows();
    emit workspacesChanged();
    emit focusedWorkspaceChanged();

    QSet<QString> currentWorkspaceOutputs;
    for (const auto& v : wsList) {
        const QString out = v.toMap().value(QStringLiteral("output")).toString();
        if (!out.isEmpty()) {
            currentWorkspaceOutputs.insert(out);
        }
    }
    if (m_lastWorkspaceOutputs != currentWorkspaceOutputs) {
        m_lastWorkspaceOutputs = currentWorkspaceOutputs;
        fetchOutputs();
    }
}

void NiriIpc::handleWindowsChanged(const QJsonObject& data) {
    const QJsonArray winArray = data.value(QStringLiteral("windows")).toArray();
    QVariantList winList = jsonArrayToVariantList(winArray);

    for (int i = 0; i < winList.size(); ++i) {
        auto w = winList.at(i).toMap();
        if (!w.contains(QStringLiteral("layout"))) {
            w[QStringLiteral("layout")] = QVariantMap();
            winList[i] = w;
        }
    }

    m_windowsModel->resetData(winList);

    sortWindowsList();
    rebuildWindowIndex();
    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowsChanged();
    emit layoutChanged();
}

void NiriIpc::handleWindowOpenedOrChanged(const QJsonObject& data) {
    const QJsonObject winObj = data.value(QStringLiteral("window")).toObject();
    if (winObj.isEmpty()) return;

    const QVariantMap window = jsonObjectToVariantMap(winObj);
    const qint64 winId = window.value(QStringLiteral("id")).toLongLong();

    const int existingIdx = findWindowIndexById(winId);

    if (existingIdx >= 0) {
        auto existing = m_windowsModel->items().at(existingIdx).toMap();
        for (auto it = window.begin(); it != window.end(); ++it) {
            existing[it.key()] = it.value();
        }
        m_windowsModel->setItem(existingIdx, existing);
    } else {
        m_windowsModel->appendItem(window);
    }

    sortWindowsList();
    rebuildWindowIndex();

    if (window.value(QStringLiteral("is_focused")).toBool()) {
        m_focusedWindowId = QString::number(winId);
        m_focusedWindowIndex = findWindowIndexById(winId);
    }

    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowsChanged();
    emit layoutChanged();
    emit windowOpenedOrChanged(window);
}

void NiriIpc::handleWindowClosed(const QJsonObject& data) {
    const qint64 closedId = data.value(QStringLiteral("id")).toInteger();

    // Protect any in-flight or queued column move transactions referencing this window
    invalidateClosedWindowInTransactions(closedId);

    const int idx = findWindowIndexById(closedId);
    if (idx >= 0) {
        m_windowsModel->removeItem(idx);
        rebuildWindowIndex();
    }

    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowClosed(closedId);
    emit windowsChanged();
    emit layoutChanged();
}

void NiriIpc::handleWindowFocusChanged(const QJsonObject& data) {
    qint64 focusId = -1;
    if (data.contains(QStringLiteral("id")) && !data.value(QStringLiteral("id")).isNull()) {
        focusId = data.value(QStringLiteral("id")).toInteger();
        m_focusedWindowId = QString::number(focusId);
        m_focusedWindowIndex = findWindowIndexById(focusId);
    } else {
        m_focusedWindowId.clear();
        m_focusedWindowIndex = -1;
    }

    updateFocusedWindowFields();
    emit windowFocusChanged(focusId);
}

void NiriIpc::handleWindowLayoutsChanged(const QJsonObject& data) {
    const QJsonArray changes = data.value(QStringLiteral("changes")).toArray();
    if (changes.isEmpty()) return;

    bool structuralChange = false;
    bool sizeChange = false;
    bool viewportChange = false;

    for (const auto& change : changes) {
        const QJsonArray pair = change.toArray();
        if (pair.size() != 2) continue;

        const qint64 id = pair.at(0).toInteger();
        const auto newLayout = pair.at(1).toObject().toVariantMap();

        const int idx = findWindowIndexById(id);
        if (idx >= 0) {
            auto w = m_windowsModel->items().at(idx).toMap();
            const auto oldLayout = w.value(QStringLiteral("layout")).toMap();

            const auto oldPos = oldLayout.value(QStringLiteral("pos_in_scrolling_layout")).toList();
            const auto newPos = newLayout.value(QStringLiteral("pos_in_scrolling_layout")).toList();
            if (oldPos != newPos) {
                structuralChange = true;
            }

            const auto oldSize = oldLayout.value(QStringLiteral("window_size")).toList();
            const auto newSize = newLayout.value(QStringLiteral("window_size")).toList();
            const auto oldTile = oldLayout.value(QStringLiteral("tile_size")).toList();
            const auto newTile = newLayout.value(QStringLiteral("tile_size")).toList();
            if (oldSize != newSize || oldTile != newTile) {
                sizeChange = true;
            }

            const auto oldView = oldLayout.value(QStringLiteral("tile_pos_in_workspace_view")).toList();
            const auto newView = newLayout.value(QStringLiteral("tile_pos_in_workspace_view")).toList();
            if (oldView != newView) {
                viewportChange = true;
            }

            if (oldPos != newPos || oldSize != newSize || oldTile != newTile) {
                w[QStringLiteral("layout")] = newLayout;
                m_windowsModel->setItem(idx, w);
            } else if (oldView != newView) {
                // Silent O(1) update without model reset or row dataChanged() (GEMINI.md §7 invariant)
                w[QStringLiteral("layout")] = newLayout;
                m_windowsModel->updateItemSilent(idx, w);
            }
        }
    }

    if (!structuralChange && !sizeChange) {
        // Sub-pixel viewport scroll frames do NOT trigger resetData() or windowsChanged().
        // Coalesce lightweight viewportChanged() notifications (~33Hz) for RibbonStrip mini-map.
        if (viewportChange && !m_viewportThrottleTimer.isActive()) {
            m_viewportThrottleTimer.start();
        }
        return;
    }

    if (structuralChange) {
        sortWindowsList();
        rebuildWindowIndex();

        if (!m_focusedWindowId.isEmpty()) {
            m_focusedWindowIndex = findWindowIndexById(m_focusedWindowId.toLongLong());
        }
    }

    updateFocusedWindowFields();
    emit windowsChanged();
    emit layoutChanged();
    emit viewportChanged();
}

void NiriIpc::handleOutputsChanged(const QJsonObject& data) {
    const auto outputs = data.value(QStringLiteral("outputs"));
    if (outputs.isObject()) {
        m_outputs = outputs.toObject().toVariantMap();
    } else {
        m_outputs = data.toVariantMap();
    }
    emit outputsChanged();
}

void NiriIpc::handleKeyboardLayoutsChanged(const QJsonObject& data) {
    const QJsonObject kb = data.value(QStringLiteral("keyboard_layouts")).toObject();
    if (kb.isEmpty()) {
        const QJsonArray names = data.value(QStringLiteral("names")).toArray();
        if (!names.isEmpty()) {
            m_kbLayoutsArray = jsonArrayToVariantList(names);
            QStringList namesList;
            for (const auto& v : m_kbLayoutsArray) {
                namesList.append(v.toString());
            }
            m_kbLayouts = namesList.join(QStringLiteral(","));

            m_kbLayoutIndex = data.value(QStringLiteral("current_idx")).toInt(0);
            emit keyboardChanged();
            return;
        }
        m_kbLayoutsArray.clear();
        m_kbLayouts = QStringLiteral("?");
        m_kbLayoutIndex = 0;
        emit keyboardChanged();
        return;
    }

    const QJsonArray names = kb.value(QStringLiteral("names")).toArray();
    m_kbLayoutsArray = jsonArrayToVariantList(names);

    QStringList namesList;
    for (const auto& v : m_kbLayoutsArray) {
        namesList.append(v.toString());
    }
    m_kbLayouts = namesList.isEmpty() ? QStringLiteral("?") : namesList.join(QStringLiteral(","));

    const int idx = kb.value(QStringLiteral("current_idx")).toInt(0);
    m_kbLayoutIndex = (idx >= 0 && idx < m_kbLayoutsArray.size()) ? idx : 0;

    emit keyboardChanged();
}

void NiriIpc::handleOverviewOpenedOrClosed(const QJsonObject& data) {
    const bool isOpen = data.value(QStringLiteral("is_open")).toBool();
    if (m_inOverview != isOpen) {
        m_inOverview = isOpen;
        emit inOverviewChanged();
    }
}

// ── Internal Helpers ─────────────────────────────────────────────────────────

void NiriIpc::updateCurrentOutputWorkspaces() {
    if (m_focusedMonitorName.isEmpty()) {
        m_currentOutputWorkspaces = m_workspacesModel->items();
        return;
    }

    m_currentOutputWorkspaces.clear();
    const auto& wsList = m_workspacesModel->items();
    for (const auto& v : wsList) {
        if (v.toMap().value(QStringLiteral("output")).toString() == m_focusedMonitorName) {
            m_currentOutputWorkspaces.append(v);
        }
    }
}

void NiriIpc::updateWorkspaceHasWindows() {
    QVariantMap newState;
    const auto& wsList = m_workspacesModel->items();
    for (const auto& wsV : wsList) {
        const auto ws = wsV.toMap();
        newState[QString::number(ws.value(QStringLiteral("idx")).toInt() + 1)] = false;
    }

    const auto& winList = m_windowsModel->items();
    for (const auto& winV : winList) {
        const auto win = winV.toMap();
        const int wsId = win.value(QStringLiteral("workspace_id")).toInt();
        const int idx = getWorkspaceIdxById(wsId);
        if (idx >= 0) {
            newState[QString::number(idx + 1)] = true;
        }
    }

    if (m_workspaceHasWindows != newState) {
        m_workspaceHasWindows = newState;
        emit workspaceHasWindowsChanged();
    }
}

void NiriIpc::updateFocusedWindowFields() {
    const auto& winList = m_windowsModel->items();
    if (m_focusedWindowIndex >= 0 && m_focusedWindowIndex < winList.size()) {
        const auto win = winList.at(m_focusedWindowIndex).toMap();
        QString title = win.value(QStringLiteral("title")).toString();
        while (!title.isEmpty() && title.at(0).unicode() < 0x20) {
            title.remove(0, 1);
        }
        m_focusedWindowTitle = title.isEmpty() ? QStringLiteral("(Unnamed window)") : title;
        m_focusedWindowClass = win.value(QStringLiteral("app_id")).toString();
        m_focusedWindow = win;

        const auto layout = win.value(QStringLiteral("layout")).toMap();
        const auto pos = layout.value(QStringLiteral("pos_in_scrolling_layout")).toList();
        if (pos.size() >= 2) {
            const int currentCol = pos.at(0).toInt();
            if (m_lastFocusedColumn >= 0) {
                const QString newDir = currentCol > m_lastFocusedColumn ? QStringLiteral("right")
                                     : currentCol < m_lastFocusedColumn ? QStringLiteral("left")
                                     : QStringLiteral("none");
                if (m_scrollDirection != newDir) {
                    m_scrollDirection = newDir;
                    emit scrollDirectionChanged();
                }
            }
            m_lastFocusedColumn = currentCol;
        }

        m_lastFocusedWindow = win;
        emit lastFocusedWindowChanged();
    } else {
        m_focusedWindowTitle.clear();
        m_focusedWindowClass = QStringLiteral("Desktop");
        m_focusedWindow.clear();
    }
    emit focusedWindowChanged();
}

void NiriIpc::sortWindowsList() {
    QVariantList winList = m_windowsModel->items();
    std::sort(winList.begin(), winList.end(), [](const QVariant& a, const QVariant& b) {
        const auto aLayout = a.toMap().value(QStringLiteral("layout")).toMap();
        const auto bLayout = b.toMap().value(QStringLiteral("layout")).toMap();
        const auto aPos = aLayout.value(QStringLiteral("pos_in_scrolling_layout")).toList();
        const auto bPos = bLayout.value(QStringLiteral("pos_in_scrolling_layout")).toList();
        const int ax = aPos.size() >= 1 ? aPos.at(0).toInt() : 0;
        const int ay = aPos.size() >= 2 ? aPos.at(1).toInt() : 0;
        const int bx = bPos.size() >= 1 ? bPos.at(0).toInt() : 0;
        const int by = bPos.size() >= 2 ? bPos.at(1).toInt() : 0;
        if (ax != bx) return ax < bx;
        return ay < by;
    });
    m_windowsModel->resetData(winList);
}

void NiriIpc::rebuildWindowIndex() {
    m_windowIndex.clear();
    const auto& winList = m_windowsModel->items();
    m_windowIndex.reserve(winList.size());
    for (int i = 0; i < winList.size(); ++i) {
        const qint64 id = winList.at(i).toMap().value(QStringLiteral("id")).toLongLong();
        m_windowIndex.insert(id, i);
    }
}

int NiriIpc::findWindowIndexById(qint64 id) const {
    const auto it = m_windowIndex.find(id);
    return (it != m_windowIndex.end()) ? it.value() : -1;
}

// ── LED Watchers (capslock/numlock via /sys/class/leds) ──────────────────────

void NiriIpc::setupLedWatchers() {
    QDir ledsDir(QStringLiteral("/sys/class/leds"));
    if (!ledsDir.exists()) return;

    const auto entries = ledsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const auto& entry : entries) {
        const QString brightnessPath = ledsDir.filePath(entry) + QStringLiteral("/brightness");
        if (!QFile::exists(brightnessPath)) continue;

        if (entry.contains(QStringLiteral("capslock"), Qt::CaseInsensitive)) {
            m_capsLockPath = brightnessPath;
        } else if (entry.contains(QStringLiteral("numlock"), Qt::CaseInsensitive)) {
            m_numLockPath = brightnessPath;
        }
    }

    readLedState();

    if (!m_capsLockPath.isEmpty() || !m_numLockPath.isEmpty()) {
        m_ledPollTimer.setInterval(1000);
        connect(&m_ledPollTimer, &QTimer::timeout, this, &NiriIpc::readLedState);
        m_ledPollTimer.start();
    }
}

void NiriIpc::readLedState() {
    auto readBrightness = [](const QString& path) -> bool {
        if (path.isEmpty()) return false;
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) return false;
        const QByteArray data = file.readAll().trimmed();
        return data.toInt() > 0;
    };

    const bool newCaps = readBrightness(m_capsLockPath);
    const bool newNum = readBrightness(m_numLockPath);

    if (m_capsLock != newCaps) {
        m_capsLock = newCaps;
        emit capsLockChanged();
    }
    if (m_numLock != newNum) {
        m_numLock = newNum;
        emit numLockChanged();
    }
}

} // namespace caelestia
