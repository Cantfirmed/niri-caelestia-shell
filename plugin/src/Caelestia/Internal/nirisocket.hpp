#pragma once

#include <qbytearray.h>
#include <qjsonobject.h>
#include <qlocalsocket.h>
#include <qobject.h>
#include <qtimer.h>

#include <deque>
#include <functional>

namespace caelestia {

/// Resolve active Niri IPC socket path from $NIRI_SOCKET or runtime directory auto-discovery.
QString resolveNiriSocketPath();

/// Dedicated EventStream connection to niri's IPC socket.
/// Connects, sends "EventStream", then emits events continuously.
class NiriEventSocket : public QObject {
    Q_OBJECT

public:
    explicit NiriEventSocket(QObject* parent = nullptr);

    void connectToNiri();
    void disconnectFromNiri();
    [[nodiscard]] bool isConnected() const;

signals:
    void connected();
    void disconnected();
    void eventReceived(const QJsonObject& event);

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onError(QLocalSocket::LocalSocketError error);

private:
    void processLine(const QByteArray& line);
    void scheduleReconnect();

    QLocalSocket* m_socket = nullptr;
    QTimer m_reconnectTimer;
    QByteArray m_readBuffer;
    int m_reconnectDelay = 1000;
    bool m_handshakeDone = false;
};

/// Persistent request/action connection to niri's IPC socket.
/// Maintains a warm AF_UNIX connection separate from EventStream so sequential
/// multi-step transactions (Focus -> MoveColumnToIndex -> RestoreFocus) execute
/// with sub-100us round-trip latency and zero per-request socket allocation.
class NiriRequestSocket : public QObject {
    Q_OBJECT

public:
    using Callback = std::function<void(bool ok, const QJsonObject& response)>;

    explicit NiriRequestSocket(QObject* parent = nullptr);

    /// Send a request and receive response via callback.
    void request(const QByteArray& payload, Callback callback);

    /// Send an action (fire-and-forget, response discarded).
    void action(const QByteArray& payload);

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onError(QLocalSocket::LocalSocketError error);

private:
    struct PendingRequest {
        QByteArray payload;
        Callback callback; // nullptr for fire-and-forget
    };

    void processQueue();
    void writeCurrent();
    void failCurrent(const QJsonObject& errObj = QJsonObject());

    QLocalSocket* m_socket = nullptr;
    QByteArray m_readBuffer;
    std::deque<PendingRequest> m_queue;
    PendingRequest m_activeRequest;
    bool m_hasActive = false;
    bool m_retriedCurrent = false;
};

} // namespace caelestia
