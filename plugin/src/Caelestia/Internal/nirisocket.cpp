#include "nirisocket.hpp"

#include <qdebug.h>
#include <qdir.h>
#include <qfileinfo.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qlocalsocket.h>
#include <QProcessEnvironment>
#include <sys/socket.h>
#include <unistd.h>

namespace caelestia {

QString resolveNiriSocketPath() {
    const auto env = QProcessEnvironment::systemEnvironment();
    const QString envSock = env.value(QStringLiteral("NIRI_SOCKET"));
    if (!envSock.isEmpty() && QFileInfo::exists(envSock)) {
        return envSock;
    }

    QStringList searchDirs;
    const QString xdgRuntime = env.value(QStringLiteral("XDG_RUNTIME_DIR"));
    if (!xdgRuntime.isEmpty()) {
        searchDirs.append(xdgRuntime);
    }
    const QString runUserDir = QStringLiteral("/run/user/%1").arg(::getuid());
    if (!searchDirs.contains(runUserDir)) {
        searchDirs.append(runUserDir);
    }

    for (const QString& dirPath : searchDirs) {
        QDir dir(dirPath);
        if (!dir.exists()) {
            continue;
        }
        const QFileInfoList entries = dir.entryInfoList(
            {QStringLiteral("niri*.sock")},
            QDir::System | QDir::Files,
            QDir::Time
        );
        if (!entries.isEmpty()) {
            return entries.first().absoluteFilePath();
        }
    }

    return envSock;
}

// ── NiriEventSocket ──────────────────────────────────────────────────────────

NiriEventSocket::NiriEventSocket(QObject* parent)
    : QObject(parent)
    , m_socket(new QLocalSocket(this)) {

    m_reconnectTimer.setSingleShot(true);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &NiriEventSocket::connectToNiri);

    connect(m_socket, &QLocalSocket::connected, this, &NiriEventSocket::onConnected);
    connect(m_socket, &QLocalSocket::disconnected, this, &NiriEventSocket::onDisconnected);
    connect(m_socket, &QLocalSocket::readyRead, this, &NiriEventSocket::onReadyRead);
    connect(m_socket, &QLocalSocket::errorOccurred, this, &NiriEventSocket::onError);
}

void NiriEventSocket::connectToNiri() {
    const QString path = resolveNiriSocketPath();
    if (path.isEmpty()) {
        qWarning() << "NiriEventSocket: Could not locate Niri IPC socket";
        scheduleReconnect();
        return;
    }

    if (m_socket->state() != QLocalSocket::UnconnectedState) {
        m_socket->abort();
    }

    m_readBuffer.clear();
    m_handshakeDone = false;
    m_socket->connectToServer(path);
}

void NiriEventSocket::disconnectFromNiri() {
    m_reconnectTimer.stop();
    if (m_socket->state() != QLocalSocket::UnconnectedState) {
        m_socket->abort();
    }
}

bool NiriEventSocket::isConnected() const {
    return m_socket->state() == QLocalSocket::ConnectedState && m_handshakeDone;
}

void NiriEventSocket::onConnected() {
    qDebug() << "NiriEventSocket: Connected, starting event stream";
    const qintptr fd = m_socket->socketDescriptor();
    if (fd >= 0) {
        int rcvbuf = 1024 * 1024; // 1MB buffer to prevent overflows during event bursts
        ::setsockopt(static_cast<int>(fd), SOL_SOCKET, SO_RCVBUF, &rcvbuf, static_cast<socklen_t>(sizeof(rcvbuf)));
    }
    m_socket->write(QByteArrayLiteral("\"EventStream\"\n"));
    m_socket->flush();
}

void NiriEventSocket::onDisconnected() {
    qDebug() << "NiriEventSocket: Disconnected";
    m_handshakeDone = false;
    emit disconnected();
    scheduleReconnect();
}

void NiriEventSocket::onReadyRead() {
    m_readBuffer.append(m_socket->readAll());

    int pos = 0;
    while ((pos = static_cast<int>(m_readBuffer.indexOf('\n'))) != -1) {
        const QByteArray line = m_readBuffer.left(pos).trimmed();
        m_readBuffer.remove(0, pos + 1);
        if (!line.isEmpty()) {
            processLine(line);
        }
    }
}

void NiriEventSocket::processLine(const QByteArray& line) {
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(line, &err);
    if (err.error != QJsonParseError::NoError) {
        qWarning() << "NiriEventSocket: JSON parse error:" << err.errorString();
        return;
    }

    const QJsonObject obj = doc.object();

    if (!m_handshakeDone) {
        if (!obj.contains(QStringLiteral("Ok"))) {
            qWarning() << "NiriEventSocket: Handshake failed. Expected {\"Ok\":...}, got:" << doc.toJson(QJsonDocument::Compact);
            disconnectFromNiri();
            return;
        }

        m_handshakeDone = true;
        m_reconnectDelay = 1000;
        qDebug() << "NiriEventSocket: Event stream active";
        emit connected();
        return;
    }

    if (obj.isEmpty()) {
        qWarning() << "NiriEventSocket: Received empty event JSON payload";
        return;
    }

    emit eventReceived(obj);
}

void NiriEventSocket::onError(QLocalSocket::LocalSocketError error) {
    if (error == QLocalSocket::PeerClosedError) {
        return;
    }
    qWarning() << "NiriEventSocket: Error:" << m_socket->errorString();
    scheduleReconnect();
}

void NiriEventSocket::scheduleReconnect() {
    if (!m_reconnectTimer.isActive()) {
        qDebug() << "NiriEventSocket: Reconnecting in" << m_reconnectDelay << "ms";
        m_reconnectTimer.start(m_reconnectDelay);
        m_reconnectDelay = qMin(m_reconnectDelay * 2, 5000);
    }
}

// ── NiriRequestSocket ────────────────────────────────────────────────────────

NiriRequestSocket::NiriRequestSocket(QObject* parent)
    : QObject(parent)
    , m_socket(new QLocalSocket(this)) {

    connect(m_socket, &QLocalSocket::connected, this, &NiriRequestSocket::onConnected);
    connect(m_socket, &QLocalSocket::disconnected, this, &NiriRequestSocket::onDisconnected);
    connect(m_socket, &QLocalSocket::readyRead, this, &NiriRequestSocket::onReadyRead);
    connect(m_socket, &QLocalSocket::errorOccurred, this, &NiriRequestSocket::onError);
}

void NiriRequestSocket::request(const QByteArray& payload, Callback callback) {
    m_queue.push_back({payload, std::move(callback)});
    if (!m_hasActive) {
        processQueue();
    }
}

void NiriRequestSocket::action(const QByteArray& payload) {
    m_queue.push_back({payload, nullptr});
    if (!m_hasActive) {
        processQueue();
    }
}

void NiriRequestSocket::processQueue() {
    if (m_hasActive) {
        return;
    }
    if (m_queue.empty()) {
        return;
    }

    m_activeRequest = std::move(m_queue.front());
    m_queue.pop_front();
    m_hasActive = true;
    m_retriedCurrent = false;

    if (m_socket->state() == QLocalSocket::ConnectedState) {
        writeCurrent();
        return;
    }

    if (m_socket->state() == QLocalSocket::ConnectingState) {
        return;
    }

    const QString path = resolveNiriSocketPath();
    if (path.isEmpty()) {
        qWarning() << "NiriRequestSocket: Could not locate Niri IPC socket";
        failCurrent();
        return;
    }

    m_readBuffer.clear();
    m_socket->connectToServer(path);
}

void NiriRequestSocket::writeCurrent() {
    if (!m_hasActive) {
        return;
    }
    QByteArray line = m_activeRequest.payload;
    if (!line.endsWith('\n')) {
        line.append('\n');
    }
    m_socket->write(line);
    m_socket->flush();
}

void NiriRequestSocket::onConnected() {
    writeCurrent();
}

void NiriRequestSocket::onReadyRead() {
    m_readBuffer.append(m_socket->readAll());

    int nlPos = 0;
    while ((nlPos = static_cast<int>(m_readBuffer.indexOf('\n'))) != -1) {
        const QByteArray line = m_readBuffer.left(nlPos).trimmed();
        m_readBuffer.remove(0, nlPos + 1);
        if (line.isEmpty() || !m_hasActive) {
            continue;
        }

        Callback cb = std::move(m_activeRequest.callback);
        m_activeRequest = {};
        m_hasActive = false;
        m_retriedCurrent = false;

        if (cb) {
            QJsonParseError err;
            const QJsonDocument doc = QJsonDocument::fromJson(line, &err);
            if (err.error != QJsonParseError::NoError) {
                qWarning() << "NiriRequestSocket: JSON parse error:" << err.errorString();
                cb(false, QJsonObject());
            } else {
                const QJsonObject obj = doc.object();
                if (obj.contains(QStringLiteral("Err"))) {
                    qWarning() << "NiriRequestSocket: IPC returned error:" << obj.value(QStringLiteral("Err"));
                    cb(false, obj);
                } else if (obj.contains(QStringLiteral("Ok"))) {
                    cb(true, QJsonObject{{QStringLiteral("result"), obj.value(QStringLiteral("Ok"))}});
                } else {
                    qWarning() << "NiriRequestSocket: Unrecognized IPC response schema:" << doc.toJson(QJsonDocument::Compact);
                    cb(false, obj);
                }
            }
        }

        processQueue();
    }
}

void NiriRequestSocket::onDisconnected() {
    m_readBuffer.clear();
    if (!m_hasActive) {
        return;
    }

    // If the persistent socket was closed by the peer while idle right before our write,
    // transparently reconnect once before failing the in-flight request.
    if (!m_retriedCurrent) {
        m_retriedCurrent = true;
        const QString path = resolveNiriSocketPath();
        if (!path.isEmpty()) {
            m_socket->connectToServer(path);
            return;
        }
    }
    failCurrent();
}

void NiriRequestSocket::onError(QLocalSocket::LocalSocketError error) {
    if (error == QLocalSocket::PeerClosedError && !m_retriedCurrent && m_hasActive) {
        // Handled in onDisconnected retry path
        return;
    }
    qWarning() << "NiriRequestSocket: Socket error:" << m_socket->errorString();
    m_socket->abort();
    m_readBuffer.clear();
    if (m_hasActive) {
        failCurrent();
    }
}

void NiriRequestSocket::failCurrent(const QJsonObject& errObj) {
    if (!m_hasActive) {
        return;
    }
    Callback cb = std::move(m_activeRequest.callback);
    m_activeRequest = {};
    m_hasActive = false;
    m_retriedCurrent = false;
    if (cb) {
        cb(false, errObj);
    }
    processQueue();
}

} // namespace caelestia
