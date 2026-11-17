// Halo: a KDE app for lighting and key settings on gaming keyboards and mice.
// It talks to devices through OpenLinkHub, which it can run itself.
// SPDX-License-Identifier: GPL-3.0-or-later

#include <QAction>
#include <QApplication>
#include <QClipboard>
#include <QCommandLineParser>
#include <QCryptographicHash>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QIcon>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMenu>
#include <QMimeDatabase>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QSystemTrayIcon>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

static const QString APP_ID = QStringLiteral("io.github.mattehrhart.Halo");

static QString dataRoot()
{
    // A fixed sub-folder, so it does not move if the organization name changes.
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/halo");
}

// Looks up the diagram Halo draws for a device model: its outline and where
// its keys or buttons are. Diagrams ship inside the app (src/devices/).
class DeviceImages : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    // "K70 MAX" -> the contents of devices/k70-max.json; empty for a model
    // that has no diagram yet.
    Q_INVOKABLE QVariantMap info(const QString &product) const
    {
        QString slug = product.toLower().trimmed();
        slug.replace(QLatin1Char(' '), QLatin1Char('-'));
        QFile file(QStringLiteral(":/devices/") + slug + QStringLiteral(".json"));
        if (!file.open(QIODevice::ReadOnly)) {
            return {};
        }
        return QJsonDocument::fromJson(file.readAll()).object().toVariantMap();
    }

    // The traced outline that best fits a product name, for models with no
    // diagram of their own: {name, keyboard, views}. Empty if nothing fits.
    // Names differ between sources ("SCIMITAR ELITE" here, "SCIMITAR RGB
    // ELITE WIRELESS" there), so they are compared word by word.
    Q_INVOKABLE QVariantMap outline(const QString &product, bool wireless)
    {
        if (m_outlines.isEmpty()) {
            QFile file(QStringLiteral(":/devices/outlines.json"));
            if (file.open(QIODevice::ReadOnly)) {
                m_outlines = QJsonDocument::fromJson(file.readAll()).object();
            }
        }
        const QStringList wanted = words(product);
        if (wanted.isEmpty()) {
            return {};
        }
        double best = 0;
        QString bestKey;
        for (auto it = m_outlines.constBegin(); it != m_outlines.constEnd(); ++it) {
            const QStringList have = words(it.value().toObject().value(QStringLiteral("name")).toString());
            // The model family ("K70", "SCIMITAR") has to match.
            if (have.isEmpty() || have.first() != wanted.first()) {
                continue;
            }
            // A wireless receiver is its own product, never a stand-in for the device.
            if (have.contains(QStringLiteral("RECEIVER")) != wanted.contains(QStringLiteral("RECEIVER"))) {
                continue;
            }
            double score = 0;
            for (const QString &word : wanted) {
                score += have.contains(word) ? 2 : -1;
            }
            for (const QString &word : have) {
                if (!wanted.contains(word) && word != QLatin1String("WIRELESS")) {
                    score -= 0.5;
                }
            }
            if (have.contains(QStringLiteral("WIRELESS")) == wireless) {
                score += 0.75;
            }
            if (score > best) {
                best = score;
                bestKey = it.key();
            }
        }
        return bestKey.isEmpty() ? QVariantMap() : m_outlines.value(bestKey).toObject().toVariantMap();
    }

private:
    // A name as its meaningful words: upper case, with filler dropped.
    static QStringList words(const QString &name)
    {
        static const QStringList filler{QStringLiteral("RGB"), QStringLiteral("GAMING"), QStringLiteral("CORSAIR"),
                                        QStringLiteral("MOUSE"), QStringLiteral("KEYBOARD"), QStringLiteral("HEADSET")};
        QStringList out;
        const QStringList parts = name.toUpper().split(QRegularExpression(QStringLiteral("[^A-Z0-9]+")), Qt::SkipEmptyParts);
        for (const QString &part : parts) {
            if (!filler.contains(part)) {
                out << part;
            }
        }
        return out;
    }

    QJsonObject m_outlines;
};

// Runs the copy of OpenLinkHub that ships with Halo, when no other copy is
// already answering, and reports what a first-time setup still needs.
class HubService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool bundled READ bundled CONSTANT)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(QString problem READ problem NOTIFY runningChanged)
public:
    explicit HubService(QObject *parent = nullptr)
        : QObject(parent)
    {
        connect(&m_process, &QProcess::stateChanged, this, &HubService::runningChanged);
        connect(&m_process, &QProcess::errorOccurred, this, [this] {
            m_problem = m_process.errorString();
            Q_EMIT runningChanged();
        });
    }

    ~HubService() override
    {
        stop();
    }

    // Where the bundled copy is installed; HALO_OPENLINKHUB overrides it for testing.
    static QString bundleDir()
    {
        const QString custom = qEnvironmentVariable("HALO_OPENLINKHUB");
        return custom.isEmpty() ? QStringLiteral("/app/lib/openlinkhub") : custom;
    }

    bool bundled() const
    {
        return QFileInfo::exists(bundleDir() + QStringLiteral("/OpenLinkHub"));
    }

    bool running() const
    {
        return m_process.state() != QProcess::NotRunning;
    }

    QString problem() const
    {
        return m_problem;
    }

    // OpenLinkHub keeps its settings beside itself, so it runs from a copy in
    // the data folder; the copy is refreshed when the bundled version changes.
    Q_INVOKABLE void start()
    {
        if (running() || !bundled()) {
            return;
        }
        const QString work = dataRoot() + QStringLiteral("/openlinkhub");
        // A fingerprint of the bundled program, so any new build is noticed.
        QString stamp;
        QFile program(bundleDir() + QStringLiteral("/OpenLinkHub"));
        if (program.open(QIODevice::ReadOnly)) {
            QCryptographicHash hash(QCryptographicHash::Sha256);
            hash.addData(&program);
            stamp = QString::fromLatin1(hash.result().toHex());
        }
        QFile marker(work + QStringLiteral("/.halo-bundle"));
        QString have;
        if (marker.open(QIODevice::ReadOnly)) {
            have = QString::fromUtf8(marker.readAll()).trimmed();
            marker.close();
        }
        if (have != stamp) {
            copyTree(bundleDir(), work);
            if (marker.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                marker.write(stamp.toUtf8());
            }
        }
        m_problem.clear();
        m_process.setWorkingDirectory(work);
        m_process.setProcessChannelMode(QProcess::ForwardedChannels);
        m_process.start(work + QStringLiteral("/OpenLinkHub"), {});
    }

    Q_INVOKABLE void restart()
    {
        stop();
        start();
    }

    Q_INVOKABLE void stop()
    {
        if (!running()) {
            return;
        }
        m_process.terminate();
        if (!m_process.waitForFinished(3000)) {
            m_process.kill();
            m_process.waitForFinished(1000);
        }
    }

    // How many supported devices are plugged in, and whether this user may
    // open them. Without the permission rule only root can.
    Q_INVOKABLE QVariantMap access() const
    {
        int found = 0;
        int usable = 0;
        QDirIterator it(QStringLiteral("/sys/class/hidraw"), QDir::Dirs | QDir::NoDotAndDotDot);
        while (it.hasNext()) {
            const QString node = it.next();
            QFile info(node + QStringLiteral("/device/uevent"));
            if (!info.open(QIODevice::ReadOnly) || !info.readAll().contains(":00001B1C:")) {
                continue;
            }
            ++found;
            QFile device(QStringLiteral("/dev/") + QFileInfo(node).fileName());
            if (device.open(QIODevice::ReadWrite)) {
                ++usable;
            }
        }
        return {{QStringLiteral("found"), found}, {QStringLiteral("usable"), usable}};
    }

    // Writes the permission rule where the user can reach it and returns the
    // command that installs it. The rule gives the person at the keyboard
    // access to the devices, with no group to join and no restart.
    Q_INVOKABLE QString rulesCommand() const
    {
        QFile source(bundleDir() + QStringLiteral("/99-openlinkhub.rules"));
        const QString target = dataRoot() + QStringLiteral("/60-halo-devices.rules");
        // No command without the file it copies (no bundled OpenLinkHub,
        // or the data folder cannot be written).
        if (!source.open(QIODevice::ReadOnly)) {
            return QString();
        }
        QString rules = QString::fromUtf8(source.readAll());
        rules.replace(QStringLiteral("OWNER=\"openlinkhub\""), QStringLiteral("TAG+=\"uaccess\""));
        rules.replace(QStringLiteral("GROUP=\"openlinkhub\""), QStringLiteral("TAG+=\"uaccess\""));
        QDir().mkpath(dataRoot());
        QFile out(target);
        if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate) || out.write(rules.toUtf8()) < 0) {
            return QString();
        }
        out.close();
        return QStringLiteral("sudo cp \"%1\" /etc/udev/rules.d/ && sudo udevadm control --reload && sudo udevadm trigger").arg(target);
    }

    Q_INVOKABLE void copy(const QString &text) const
    {
        QGuiApplication::clipboard()->setText(text);
    }

    // Sends a picture to OpenLinkHub for its screens (a form upload, which
    // the QML side cannot do with a file). Answers through uploaded().
    Q_INVOKABLE void upload(const QString &address, const QUrl &picture)
    {
        auto *file = new QFile(picture.toLocalFile());
        if (!file->open(QIODevice::ReadOnly)) {
            const QString why = file->errorString();
            delete file;
            Q_EMIT uploaded(false, QStringLiteral("Could not open the file: ") + why);
            return;
        }
        auto *form = new QHttpMultiPart(QHttpMultiPart::FormDataType);
        QHttpPart part;
        const QString name = QFileInfo(*file).fileName().replace(QLatin1Char('"'), QLatin1Char('_'));
        part.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QStringLiteral("form-data; name=\"animationFile\"; filename=\"%1\"").arg(name));
        part.setHeader(QNetworkRequest::ContentTypeHeader, QMimeDatabase().mimeTypeForFile(file->fileName()).name());
        part.setBodyDevice(file);
        file->setParent(form);
        form->append(part);
        QNetworkReply *reply = m_network.post(QNetworkRequest(QUrl(address)), form);
        form->setParent(reply);
        connect(reply, &QNetworkReply::finished, this, [this, reply] {
            const QByteArray body = reply->readAll();
            const int code = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const QJsonObject answer = QJsonDocument::fromJson(body).object();
            bool ok = reply->error() == QNetworkReply::NoError && code >= 200 && code < 300;
            if (ok && answer.contains(QStringLiteral("status"))) {
                ok = answer.value(QStringLiteral("status")).toInt() == 1;
            }
            QString message = answer.value(QStringLiteral("message")).toString();
            if (message.isEmpty() && !ok) {
                message = QString::fromUtf8(body).trimmed();
            }
            if (message.isEmpty() && !ok) {
                message = reply->errorString();
            }
            reply->deleteLater();
            Q_EMIT uploaded(ok, message);
        });
    }

Q_SIGNALS:
    void runningChanged();
    void uploaded(bool ok, const QString &message);

private:
    static void copyTree(const QString &from, const QString &to)
    {
        QDir().mkpath(to);
        QDirIterator it(from, QDir::AllEntries | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString path = it.next();
            const QString target = to + path.mid(from.length());
            if (it.fileInfo().isDir()) {
                QDir().mkpath(target);
                continue;
            }
            // Keep what OpenLinkHub has saved; replace only what ships with
            // it: the program, its pages, and the key layouts and
            // translations it reads but never writes.
            const bool program = path.endsWith(QStringLiteral("/OpenLinkHub")) || path.contains(QStringLiteral("/web/"))
                || path.contains(QStringLiteral("/static/")) || path.contains(QStringLiteral("/database/keyboard/"))
                || path.contains(QStringLiteral("/database/language/"));
            if (QFileInfo::exists(target)) {
                if (!program) {
                    continue;
                }
                QFile::remove(target);
            }
            QFile::copy(path, target);
            QFile::setPermissions(target, QFile::permissions(path) | QFile::WriteOwner);
        }
    }

    QProcess m_process;
    QNetworkAccessManager m_network;
    QString m_problem;
};

// The tray icon and the choices about starting up.
class Shell : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool startAtLogin READ startAtLogin WRITE setStartAtLogin NOTIFY changed)
    Q_PROPERTY(bool startMinimized READ startMinimized WRITE setStartMinimized NOTIFY changed)
    Q_PROPERTY(bool closeToTray READ closeToTray WRITE setCloseToTray NOTIFY changed)
    Q_PROPERTY(bool batteryAlerts READ batteryAlerts WRITE setBatteryAlerts NOTIFY changed)
    Q_PROPERTY(bool lightsOff READ lightsOff WRITE setLightsOff NOTIFY changed)
    Q_PROPERTY(bool trayAvailable READ trayAvailable CONSTANT)
    Q_PROPERTY(QString version READ version CONSTANT)
public:
    explicit Shell(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    bool trayAvailable() const
    {
        return QSystemTrayIcon::isSystemTrayAvailable();
    }

    QString version() const
    {
        return QCoreApplication::applicationVersion();
    }

    bool closeToTray() const
    {
        return trayAvailable() && m_settings.value(QStringLiteral("Window/closeToTray"), true).toBool();
    }

    void setCloseToTray(bool on)
    {
        if (on != closeToTray()) {
            m_settings.setValue(QStringLiteral("Window/closeToTray"), on);
            Q_EMIT changed();
        }
    }

    bool batteryAlerts() const
    {
        return m_settings.value(QStringLiteral("Alerts/battery"), true).toBool();
    }

    void setBatteryAlerts(bool on)
    {
        if (on != batteryAlerts()) {
            m_settings.setValue(QStringLiteral("Alerts/battery"), on);
            Q_EMIT changed();
        }
    }

    // Whether the user has switched every device's lights off from Halo.
    bool lightsOff() const
    {
        return m_settings.value(QStringLiteral("Lighting/off"), false).toBool();
    }

    void setLightsOff(bool off)
    {
        if (off != lightsOff()) {
            m_settings.setValue(QStringLiteral("Lighting/off"), off);
            Q_EMIT changed();
            Q_EMIT lightsRequested(off);
        }
    }

    // A desktop notification from the tray icon.
    Q_INVOKABLE void notify(const QString &title, const QString &text)
    {
        if (trayAvailable() && m_tray.isVisible()) {
            m_tray.showMessage(title, text, QIcon::fromTheme(APP_ID), 8000);
        }
    }

    bool startAtLogin() const
    {
        return m_settings.value(QStringLiteral("Startup/atLogin"), false).toBool();
    }

    bool startMinimized() const
    {
        return m_settings.value(QStringLiteral("Startup/minimized"), false).toBool();
    }

    void setStartMinimized(bool on)
    {
        if (on == startMinimized()) {
            return;
        }
        m_settings.setValue(QStringLiteral("Startup/minimized"), on);
        if (startAtLogin()) {
            applyAutostart(true);
        }
        Q_EMIT changed();
    }

    void setStartAtLogin(bool on)
    {
        if (on == startAtLogin()) {
            return;
        }
        m_settings.setValue(QStringLiteral("Startup/atLogin"), on);
        applyAutostart(on);
        Q_EMIT changed();
    }

    void attach(QQuickWindow *window)
    {
        m_window = window;
        if (!trayAvailable()) {
            return;
        }
        m_tray.setIcon(QIcon::fromTheme(APP_ID, QApplication::windowIcon()));
        m_tray.setToolTip(QStringLiteral("Halo"));

        auto *open = m_menu.addAction(QIcon::fromTheme(QStringLiteral("window")), QStringLiteral("Open Halo"));
        connect(open, &QAction::triggered, this, &Shell::showWindow);
        m_lights = m_menu.addAction(QStringLiteral("Lights Off"));
        m_lights->setCheckable(true);
        connect(m_lights, &QAction::toggled, this, &Shell::setLightsOff);
        m_menu.addSeparator();
        m_login = m_menu.addAction(QStringLiteral("Start at Login"));
        m_login->setCheckable(true);
        connect(m_login, &QAction::toggled, this, &Shell::setStartAtLogin);
        m_minimized = m_menu.addAction(QStringLiteral("Start Minimized"));
        m_minimized->setCheckable(true);
        connect(m_minimized, &QAction::toggled, this, &Shell::setStartMinimized);
        m_menu.addSeparator();
        auto *quit = m_menu.addAction(QIcon::fromTheme(QStringLiteral("application-exit")), QStringLiteral("Quit"));
        connect(quit, &QAction::triggered, qApp, &QCoreApplication::quit);
        connect(this, &Shell::changed, this, &Shell::syncMenu);
        syncMenu();

        m_tray.setContextMenu(&m_menu);
        connect(&m_tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
            if (reason == QSystemTrayIcon::Trigger) {
                if (m_window && m_window->isVisible()) {
                    m_window->hide();
                } else {
                    showWindow();
                }
            }
        });
        m_tray.show();
    }

    // The tray menu's device entries: one sub-menu per device, with its
    // battery level in the title and its profiles to switch between.
    // Each entry: serial, product, battery (-1 for none), profiles, active.
    Q_INVOKABLE void setDevices(const QVariantList &devices)
    {
        if (!m_lights) {
            return;
        }
        for (QAction *action : std::as_const(m_deviceActions)) {
            m_menu.removeAction(action);
            if (action->menu()) {
                action->menu()->deleteLater();
            } else {
                action->deleteLater();
            }
        }
        m_deviceActions.clear();
        for (const QVariant &entry : devices) {
            const QVariantMap device = entry.toMap();
            const QString serial = device.value(QStringLiteral("serial")).toString();
            const int battery = device.value(QStringLiteral("battery"), -1).toInt();
            QString title = device.value(QStringLiteral("product")).toString();
            if (battery >= 0) {
                title += QStringLiteral("  –  %1%").arg(battery);
            }
            auto *sub = new QMenu(title);
            connect(sub->addAction(QStringLiteral("Open")), &QAction::triggered, this, [this, serial] {
                showWindow();
                Q_EMIT deviceRequested(serial);
            });
            const QStringList profiles = device.value(QStringLiteral("profiles")).toStringList();
            const QString active = device.value(QStringLiteral("active")).toString();
            if (profiles.size() > 1) {
                sub->addSection(QStringLiteral("Profile"));
                for (const QString &name : profiles) {
                    QAction *pick = sub->addAction(name);
                    pick->setCheckable(true);
                    pick->setChecked(name == active);
                    connect(pick, &QAction::triggered, this, [this, serial, name] { Q_EMIT profileRequested(serial, name); });
                }
            }
            m_deviceActions << m_menu.insertMenu(m_lights, sub);
        }
        if (!devices.isEmpty()) {
            m_deviceActions << m_menu.insertSeparator(m_lights);
        }
    }

    Q_INVOKABLE Q_SCRIPTABLE void showWindow()
    {
        if (!m_window) {
            return;
        }
        m_window->show();
        m_window->raise();
        m_window->requestActivate();
    }

    Q_INVOKABLE void quit()
    {
        QCoreApplication::quit();
    }

Q_SIGNALS:
    void changed();
    void lightsRequested(bool off);
    void deviceRequested(const QString &serial);
    void profileRequested(const QString &serial, const QString &profile);

private:
    void syncMenu()
    {
        if (m_login) {
            const QSignalBlocker a(m_login);
            const QSignalBlocker b(m_minimized);
            const QSignalBlocker c(m_lights);
            m_lights->setChecked(lightsOff());
            m_login->setChecked(startAtLogin());
            m_minimized->setChecked(startMinimized());
        }
    }

    // Inside a Flatpak the desktop is asked through its portal; otherwise an
    // autostart entry is written the usual way.
    void applyAutostart(bool on)
    {
        QStringList command{QStringLiteral("halo")};
        if (startMinimized()) {
            command << QStringLiteral("--minimized");
        }
        if (QFileInfo::exists(QStringLiteral("/.flatpak-info"))) {
            QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.portal.Desktop"),
                                                               QStringLiteral("/org/freedesktop/portal/desktop"),
                                                               QStringLiteral("org.freedesktop.portal.Background"),
                                                               QStringLiteral("RequestBackground"));
            QVariantMap options{
                {QStringLiteral("reason"), QStringLiteral("Keep your device settings applied")},
                {QStringLiteral("autostart"), on},
                {QStringLiteral("commandline"), command},
            };
            call << QString() << options;
            QDBusConnection::sessionBus().asyncCall(call);
            return;
        }
        const QString path = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QStringLiteral("/autostart/")
            + APP_ID + QStringLiteral(".desktop");
        if (!on) {
            QFile::remove(path);
            return;
        }
        QDir().mkpath(QFileInfo(path).path());
        QFile file(path);
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            file.write(QStringLiteral("[Desktop Entry]\nType=Application\nName=Halo\nExec=%1\nIcon=%2\n")
                           .arg(command.join(QLatin1Char(' ')), APP_ID)
                           .toUtf8());
        }
    }

    QSettings m_settings;
    QSystemTrayIcon m_tray;
    QMenu m_menu;
    QAction *m_lights = nullptr;
    QList<QAction *> m_deviceActions;
    QAction *m_login = nullptr;
    QAction *m_minimized = nullptr;
    QQuickWindow *m_window = nullptr;
};

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setOrganizationName(QStringLiteral("halo"));
    QApplication::setOrganizationDomain(QStringLiteral("mattehrhart.github.io"));
    QApplication::setApplicationName(QStringLiteral("halo"));
    QApplication::setApplicationDisplayName(QStringLiteral("Halo"));
    QApplication::setApplicationVersion(QStringLiteral("0.2.0"));
    QApplication::setDesktopFileName(APP_ID);
    QApplication::setWindowIcon(QIcon::fromTheme(APP_ID));
    // Closing the window leaves Halo in the tray.
    QApplication::setQuitOnLastWindowClosed(false);

    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Lighting and key settings for gaming keyboards and mice."));
    parser.addHelpOption();
    parser.addVersionOption();
    QCommandLineOption hubOpt(QStringLiteral("hub"), QStringLiteral("OpenLinkHub address."), QStringLiteral("url"),
                              QStringLiteral("http://127.0.0.1:27003"));
    QCommandLineOption minimizedOpt(QStringLiteral("minimized"), QStringLiteral("Start in the tray without opening the window."));
    QCommandLineOption routeOpt(QStringLiteral("route"), QStringLiteral("Open a page at start, e.g. keyboard/actuation."),
                                QStringLiteral("route"));
    QCommandLineOption grabOpt(QStringLiteral("grab"), QStringLiteral("Save a picture of the window to this file and quit."),
                               QStringLiteral("file"));
    QCommandLineOption delayOpt(QStringLiteral("grab-delay"), QStringLiteral("Milliseconds to wait before --grab."),
                                QStringLiteral("ms"), QStringLiteral("2500"));
    QCommandLineOption sizeOpt(QStringLiteral("size"), QStringLiteral("Window size at start, e.g. 1280x800."),
                               QStringLiteral("WxH"));
    parser.addOptions({hubOpt, minimizedOpt, routeOpt, grabOpt, delayOpt, sizeOpt});
    parser.process(app);

    // One Halo at a time: a second launch just brings the first one's
    // window forward. (Test captures with --grab run on their own.)
    if (!parser.isSet(grabOpt)) {
        QDBusConnection bus = QDBusConnection::sessionBus();
        if (!bus.registerService(APP_ID)) {
            bus.call(QDBusMessage::createMethodCall(APP_ID, QStringLiteral("/Halo"), QString(), QStringLiteral("showWindow")));
            return 0;
        }
    }

    DeviceImages images;
    HubService service;
    Shell shell;
    const bool hidden = parser.isSet(minimizedOpt) && shell.trayAvailable();

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("deviceImages"), &images);
    engine.rootContext()->setContextProperty(QStringLiteral("hubService"), &service);
    engine.rootContext()->setContextProperty(QStringLiteral("shell"), &shell);
    engine.setInitialProperties({
        {QStringLiteral("hubUrl"), parser.value(hubOpt)},
        {QStringLiteral("startRoute"), parser.value(routeOpt)},
        {QStringLiteral("visible"), !hidden},
    });
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); },
                     Qt::QueuedConnection);
    engine.loadFromModule("halo", "Main");

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().value(0));
    const QStringList size = parser.value(sizeOpt).split(QLatin1Char('x'));
    if (window && size.size() == 2) {
        window->resize(size.at(0).toInt(), size.at(1).toInt());
    }
    if (window && !parser.isSet(grabOpt)) {
        shell.attach(window);
        QDBusConnection::sessionBus().registerObject(QStringLiteral("/Halo"), &shell, QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableInvokables);
    }

    if (parser.isSet(grabOpt)) {
        const QString file = parser.value(grabOpt);
        QTimer::singleShot(parser.value(delayOpt).toInt(), &app, [window, file] {
            const bool ok = window && window->grabWindow().save(file);
            QCoreApplication::exit(ok ? 0 : 2);
        });
    }

    return app.exec();
}

#include "main.moc"
