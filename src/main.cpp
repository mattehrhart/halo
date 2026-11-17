// Linkdeck: a native KDE front end for OpenLinkHub.
// SPDX-License-Identifier: GPL-3.0-or-later

#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QFileInfo>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

// Looks for user-supplied device pictures in the app's data folder, so no
// vendor artwork has to ship with the source.
class DeviceImages : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    Q_INVOKABLE QString folder() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/devices");
    }

    // "K70 MAX" -> <data>/devices/k70-max.png (or .jpg/.webp); empty if absent.
    Q_INVOKABLE QUrl find(const QString &product) const
    {
        QString slug = product.toLower().trimmed();
        slug.replace(QLatin1Char(' '), QLatin1Char('-'));
        for (const char *ext : {"png", "webp", "jpg", "jpeg"}) {
            const QString path = folder() + QLatin1Char('/') + slug + QLatin1Char('.') + QLatin1String(ext);
            if (QFileInfo::exists(path)) {
                return QUrl::fromLocalFile(path);
            }
        }
        return {};
    }
};

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("linkdeck"));
    QApplication::setApplicationDisplayName(QStringLiteral("Linkdeck"));
    QApplication::setApplicationVersion(QStringLiteral("0.1.0"));
    QApplication::setDesktopFileName(QStringLiteral("io.github.mattehrhart.linkdeck"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("io.github.mattehrhart.linkdeck")));

    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Control Corsair keyboards and mice through OpenLinkHub."));
    parser.addHelpOption();
    parser.addVersionOption();
    QCommandLineOption hubOpt(QStringLiteral("hub"), QStringLiteral("OpenLinkHub address."), QStringLiteral("url"),
                              QStringLiteral("http://127.0.0.1:27003"));
    QCommandLineOption routeOpt(QStringLiteral("route"), QStringLiteral("Open a page at start, e.g. keyboard/actuation."),
                                QStringLiteral("route"));
    QCommandLineOption grabOpt(QStringLiteral("grab"), QStringLiteral("Save a picture of the window to this file and quit."),
                               QStringLiteral("file"));
    QCommandLineOption delayOpt(QStringLiteral("grab-delay"), QStringLiteral("Milliseconds to wait before --grab."),
                                QStringLiteral("ms"), QStringLiteral("2500"));
    parser.addOptions({hubOpt, routeOpt, grabOpt, delayOpt});
    parser.process(app);

    DeviceImages images;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("deviceImages"), &images);
    engine.setInitialProperties({
        {QStringLiteral("hubUrl"), parser.value(hubOpt)},
        {QStringLiteral("startRoute"), parser.value(routeOpt)},
    });
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); },
                     Qt::QueuedConnection);
    engine.loadFromModule("linkdeck", "Main");

    if (parser.isSet(grabOpt)) {
        const QString file = parser.value(grabOpt);
        QTimer::singleShot(parser.value(delayOpt).toInt(), &app, [&engine, file] {
            auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().value(0));
            const bool ok = window && window->grabWindow().save(file);
            QCoreApplication::exit(ok ? 0 : 2);
        });
    }

    return app.exec();
}

#include "main.moc"
