#include "cpu.hpp"

#include <qdir.h>
#include <qfile.h>
#include <qregularexpression.h>

#include <cmath>

#include "sensorslib.hpp"

namespace caelestia::services {

using Qt::StringLiterals::operator""_s;

Cpu::Cpu(QObject* parent)
    : TickingService(parent) {
    readNameOnce();
    refreshFrequency();
}

QString Cpu::name() const {
    return m_name;
}

qreal Cpu::percentage() const {
    return m_percentage;
}

qreal Cpu::temperature() const {
    return m_temperature;
}

qreal Cpu::frequency() const {
    return m_frequency;
}

void Cpu::tick() {
    if (!m_nameLoaded) {
        readNameOnce();
    }
    refreshPercentage();
    refreshTemperature();
    refreshFrequency();
}

void Cpu::readNameOnce() {
    QFile f(u"/proc/cpuinfo"_s);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }
    const QByteArray data = f.readAll();
    f.close();

    static const QRegularExpression k_re(u"model name\\s*:\\s*(.+)"_s);
    const auto match = k_re.match(QString::fromLatin1(data));
    if (!match.hasMatch()) {
        return;
    }

    const QString cleaned = cleanName(match.captured(1));
    m_nameLoaded = true;
    if (cleaned == m_name) {
        return;
    }
    m_name = cleaned;
    emit nameChanged();
}

void Cpu::refreshPercentage() {
    QFile f(u"/proc/stat"_s);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }
    const QByteArray data = f.readAll();
    f.close();

    static const QRegularExpression k_re(
        u"^cpu\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)"_s);
    const auto match = k_re.match(QString::fromLatin1(data));
    if (!match.hasMatch()) {
        return;
    }

    quint64 total = 0;
    quint64 idle = 0;
    for (int i = 1; i <= 7; ++i) {
        const quint64 v = match.captured(i).toULongLong();
        total += v;
        if (i == 4 || i == 5) {
            idle += v;
        }
    }

    const quint64 totalDiff = total > m_lastTotal ? total - m_lastTotal : 0;
    const quint64 idleDiff = idle > m_lastIdle ? idle - m_lastIdle : 0;
    const qreal newPerc = totalDiff > 0 ? 1.0 - static_cast<qreal>(idleDiff) / static_cast<qreal>(totalDiff) : 0.0;

    m_lastTotal = total;
    m_lastIdle = idle;

    if (std::abs(newPerc - m_percentage) > 0.0001) {
        m_percentage = newPerc;
        emit percentageChanged();
    }
}

void Cpu::refreshTemperature() {
    const auto t = sensorslib::cpuPackageTemp();
    const qreal newTemp = t.value_or(0.0);
    if (std::abs(newTemp - m_temperature) > 0.05) {
        m_temperature = newTemp;
        emit temperatureChanged();
    }
}

void Cpu::refreshFrequency() {
    qreal maxMhz = 0.0;
    int count = 0;

    QFile f(u"/proc/cpuinfo"_s);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        while (!f.atEnd()) {
            const QByteArray line = f.readLine();
            if (line.startsWith("cpu MHz")) {
                const auto colon = line.indexOf(':');
                if (colon != -1) {
                    bool ok = false;
                    const double mhz = line.mid(colon + 1).trimmed().toDouble(&ok);
                    if (ok && mhz > 0.0) {
                        if (mhz > maxMhz) {
                            maxMhz = mhz;
                        }
                        count++;
                    }
                }
            }
        }
        f.close();
    }

    if (count > 0 && maxMhz > 0.0) {
        const qreal newGhz = maxMhz / 1000.0;
        if (std::abs(newGhz - m_frequency) > 0.01) {
            m_frequency = newGhz;
            emit frequencyChanged();
        }
        return;
    }

    // Fallback: sysfs scaling_cur_freq (for ARM or kernels without cpu MHz in cpuinfo)
    if (m_freqSysfsFiles.isEmpty()) {
        QDir cpufreqDir(u"/sys/devices/system/cpu/cpufreq"_s);
        const auto policies = cpufreqDir.entryList({ u"policy*"_s }, QDir::Dirs);
        for (const auto& policy : policies) {
            const QString path = cpufreqDir.filePath(policy) + u"/scaling_cur_freq"_s;
            if (QFile::exists(path)) {
                m_freqSysfsFiles.append(path);
            }
        }
        if (m_freqSysfsFiles.isEmpty()) {
            QDir cpuDir(u"/sys/devices/system/cpu"_s);
            const auto cpus = cpuDir.entryList({ u"cpu[0-9]*"_s }, QDir::Dirs);
            for (const auto& cpu : cpus) {
                const QString path = cpuDir.filePath(cpu) + u"/cpufreq/scaling_cur_freq"_s;
                if (QFile::exists(path)) {
                    m_freqSysfsFiles.append(path);
                }
            }
        }
    }

    quint64 maxKhz = 0;
    for (const auto& path : m_freqSysfsFiles) {
        QFile freqFile(path);
        if (freqFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QByteArray data = freqFile.readAll().trimmed();
            freqFile.close();
            bool ok = false;
            const quint64 khz = data.toULongLong(&ok);
            if (ok && khz > maxKhz) {
                maxKhz = khz;
            }
        }
    }

    if (maxKhz > 0) {
        const qreal newGhz = static_cast<qreal>(maxKhz) / 1000000.0;
        if (std::abs(newGhz - m_frequency) > 0.01) {
            m_frequency = newGhz;
            emit frequencyChanged();
        }
    }
}

QString Cpu::cleanName(QString s) {
    static const QRegularExpression k_noise(
        u"\\(R\\)|\\(TM\\)|CPU|\\d+(?:th|nd|rd|st) Gen |Core |Processor"_s, QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression k_spaces(u"\\s+"_s);

    s.replace(k_noise, {});
    s.replace(k_spaces, u" "_s);
    return s.trimmed();
}

} // namespace caelestia::services
