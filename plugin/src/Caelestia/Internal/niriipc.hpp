#pragma once

#include "nirisocket.hpp"

#include <qhash.h>
#include <qjsonarray.h>
#include <qjsonobject.h>
#include <QAbstractListModel>
#include <QList>
#include <QObject>
#include <QSet>
#include <QTimer>
#include <QVariant>
#include <QtQmlIntegration>

#include <deque>
#include <functional>

namespace caelestia {

class NiriListModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles { ObjectRole = Qt::UserRole + 1 };

    explicit NiriListModel(QObject* parent = nullptr);

    QHash<int, QByteArray> roleNames() const override;
    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;

    void resetData(const QVariantList& items);
    void appendItem(const QVariantMap& item);
    void setItem(int idx, const QVariantMap& item);
    void updateItemSilent(int idx, const QVariantMap& item);
    void removeItem(int idx);
    const QVariantList& items() const;

private:
    QVariantList m_items;
};

/// NiriIpc — QML singleton providing native IPC access to the niri compositor.
///
/// Replaces all Process-based niri msg spawning with persistent EventStream and
/// Request sockets, plus an atomic C++ transaction runner for column reordering.
class NiriIpc : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // ── Core ──
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

    // ── Workspaces ──
    Q_PROPERTY(QAbstractListModel* workspacesModel READ workspacesModel CONSTANT)
    Q_PROPERTY(QVariantList workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(int focusedWorkspaceIndex READ focusedWorkspaceIndex NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(int focusedWorkspaceId READ focusedWorkspaceId NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(QString focusedMonitorName READ focusedMonitorName NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(QVariantList currentOutputWorkspaces READ currentOutputWorkspaces NOTIFY workspacesChanged)
    Q_PROPERTY(QVariantMap workspaceHasWindows READ workspaceHasWindows NOTIFY workspaceHasWindowsChanged)

    // ── Windows ──
    Q_PROPERTY(QAbstractListModel* windowsModel READ windowsModel CONSTANT)
    Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(int focusedWindowIndex READ focusedWindowIndex NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowId READ focusedWindowId NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowTitle READ focusedWindowTitle NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowClass READ focusedWindowClass NOTIFY focusedWindowChanged)
    Q_PROPERTY(QVariantMap focusedWindow READ focusedWindow NOTIFY focusedWindowChanged)
    Q_PROPERTY(QVariantMap lastFocusedWindow READ lastFocusedWindow NOTIFY lastFocusedWindowChanged)
    Q_PROPERTY(QString scrollDirection READ scrollDirection NOTIFY scrollDirectionChanged)
    Q_PROPERTY(bool inOverview READ inOverview NOTIFY inOverviewChanged)

    // ── Outputs ──
    Q_PROPERTY(QVariantMap outputs READ outputs NOTIFY outputsChanged)

    // ── Keyboard ──
    Q_PROPERTY(QVariantList kbLayoutsArray READ kbLayoutsArray NOTIFY keyboardChanged)
    Q_PROPERTY(int kbLayoutIndex READ kbLayoutIndex NOTIFY keyboardChanged)
    Q_PROPERTY(QString kbLayouts READ kbLayouts NOTIFY keyboardChanged)
    Q_PROPERTY(QString defaultKbLayout READ defaultKbLayout NOTIFY keyboardChanged)
    Q_PROPERTY(QString kbLayout READ kbLayout NOTIFY keyboardChanged)
    Q_PROPERTY(bool capsLock READ capsLock NOTIFY capsLockChanged)
    Q_PROPERTY(bool numLock READ numLock NOTIFY numLockChanged)

public:
    explicit NiriIpc(QObject* parent = nullptr);

    // ── Property getters ──
    [[nodiscard]] bool available() const;

    [[nodiscard]] QAbstractListModel* workspacesModel() const;
    [[nodiscard]] QVariantList workspaces() const;
    [[nodiscard]] int focusedWorkspaceIndex() const;
    [[nodiscard]] int focusedWorkspaceId() const;
    [[nodiscard]] QString focusedMonitorName() const;
    [[nodiscard]] QVariantList currentOutputWorkspaces() const;
    [[nodiscard]] QVariantMap workspaceHasWindows() const;

    [[nodiscard]] QAbstractListModel* windowsModel() const;
    [[nodiscard]] QVariantList windows() const;
    [[nodiscard]] int focusedWindowIndex() const;
    [[nodiscard]] QString focusedWindowId() const;
    [[nodiscard]] QString focusedWindowTitle() const;
    [[nodiscard]] QString focusedWindowClass() const;
    [[nodiscard]] QVariantMap focusedWindow() const;
    [[nodiscard]] QVariantMap lastFocusedWindow() const;
    [[nodiscard]] QString scrollDirection() const;
    [[nodiscard]] bool inOverview() const;

    [[nodiscard]] QVariantMap outputs() const;

    [[nodiscard]] QVariantList kbLayoutsArray() const;
    [[nodiscard]] int kbLayoutIndex() const;
    [[nodiscard]] QString kbLayouts() const;
    [[nodiscard]] QString defaultKbLayout() const;
    [[nodiscard]] QString kbLayout() const;
    [[nodiscard]] bool capsLock() const;
    [[nodiscard]] bool numLock() const;

    // ── Actions & Atomic Transactions (Q_INVOKABLE for QML) ──
    Q_INVOKABLE bool action(const QString& actionName, const QVariantList& args = {});
    Q_INVOKABLE void fetchOutputs();
    Q_INVOKABLE bool moveColumnToIndex(qint64 windowId, int targetIndex, bool restoreFocus = true);
    Q_INVOKABLE bool reorderColumn(qint64 windowId, int targetIndex);
    Q_INVOKABLE bool moveGroupColumns(
        const QVariantList& windowIds,
        const QVariantList& targetIndices,
        qint64 restoreFocusWindowId = -1
    );

    // ── Workspace Helpers ──
    Q_INVOKABLE int getWorkspaceIdxById(int workspaceId) const;
    Q_INVOKABLE QVariantList getWorkspacesForOutput(const QString& outputName) const;
    Q_INVOKABLE QVariantList getWindowsByWorkspaceId(int wsId) const;
    Q_INVOKABLE QVariantList getWindowsByWorkspaceIndex(int index) const;
    Q_INVOKABLE QVariantList getActiveWorkspaceWindows() const;

signals:
    void availableChanged();
    void workspacesChanged();
    void workspaceActivated(int workspaceId, bool focused);
    void focusedWorkspaceChanged();
    void workspaceHasWindowsChanged();
    void windowsChanged();
    void windowClosed(qint64 windowId);
    void windowFocusChanged(qint64 windowId);
    void focusedWindowChanged();
    void lastFocusedWindowChanged();
    void layoutChanged();
    void viewportChanged();
    void scrollDirectionChanged();
    void inOverviewChanged();
    void outputsChanged();
    void keyboardChanged();
    void capsLockChanged();
    void numLockChanged();
    void windowOpenedOrChanged(const QVariantMap& windowData);
    void columnMoveCompleted(qint64 windowId, bool success);

private slots:
    void onEventStreamConnected();
    void onEventStreamDisconnected();
    void onEvent(const QJsonObject& event);

private:
    struct ColumnMoveStep {
        qint64 windowId = -1;
        int targetIndex = 1;
        bool cancelled = false;
    };

    struct ColumnMoveTransaction {
        QList<ColumnMoveStep> steps;
        qint64 originalFocusWindowId = -1;
        qint64 primaryWindowId = -1;
        qint64 lastMovedWindowId = -1;
        bool restoreFocus = true;
        bool anyMoved = false;
        int currentStep = 0;
        std::function<void(bool success)> callback;
    };

    void enqueueMoveTransaction(ColumnMoveTransaction tx);
    void processNextMoveTransaction();
    void executeNextMoveStep();
    void finishActiveMoveTransaction();
    void invalidateClosedWindowInTransactions(qint64 closedId);
    static QByteArray buildFocusWindowPayload(qint64 windowId);
    static QByteArray buildMoveColumnPayload(int targetIndex);

    void fetchInitialState();
    void handleWorkspacesChanged(const QJsonObject& data);
    void handleWindowsChanged(const QJsonObject& data);
    void handleWindowOpenedOrChanged(const QJsonObject& data);
    void handleWindowClosed(const QJsonObject& data);
    void handleWindowFocusChanged(const QJsonObject& data);
    void handleWindowLayoutsChanged(const QJsonObject& data);
    void handleOutputsChanged(const QJsonObject& data);
    void handleKeyboardLayoutsChanged(const QJsonObject& data);
    void handleOverviewOpenedOrClosed(const QJsonObject& data);

    void updateCurrentOutputWorkspaces();
    void updateWorkspaceHasWindows();
    void updateFocusedWindowFields();
    void sortWindowsList();
    void rebuildWindowIndex();
    int findWindowIndexById(qint64 id) const;
    void setupLedWatchers();
    void readLedState();

    NiriEventSocket m_eventSocket;
    NiriRequestSocket m_requestSocket;

    bool m_available = false;

    // Atomic column move transaction queue
    std::deque<ColumnMoveTransaction> m_moveQueue;
    ColumnMoveTransaction m_activeMoveTx;
    bool m_moveInFlight = false;

    // Workspace state
    NiriListModel* m_workspacesModel;
    int m_focusedWorkspaceIndex = -1;
    int m_focusedWorkspaceId = -1;
    QString m_focusedMonitorName;
    QVariantList m_currentOutputWorkspaces;
    QVariantMap m_workspaceHasWindows;
    QSet<QString> m_lastWorkspaceOutputs;

    // Window state
    NiriListModel* m_windowsModel;
    QHash<qint64, int> m_windowIndex; // window ID -> index in m_windows for O(1) lookup
    int m_focusedWindowIndex = -1;
    QString m_focusedWindowId;
    QString m_focusedWindowTitle;
    QString m_focusedWindowClass;
    QVariantMap m_focusedWindow;
    QVariantMap m_lastFocusedWindow;
    int m_lastFocusedColumn = -1;
    QString m_scrollDirection = QStringLiteral("none");
    bool m_inOverview = false;
    QTimer m_viewportThrottleTimer;

    // Output state
    QVariantMap m_outputs;

    // Keyboard state
    QVariantList m_kbLayoutsArray;
    int m_kbLayoutIndex = 0;
    QString m_kbLayouts = QStringLiteral("?");

    // LED state
    bool m_capsLock = false;
    bool m_numLock = false;
    QTimer m_ledPollTimer;
    QString m_capsLockPath;
    QString m_numLockPath;
};

} // namespace caelestia
