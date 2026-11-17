cmake_minimum_required(VERSION 3.22)
project(linkdeck VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Widgets)
find_package(KF6 6.0 REQUIRED COMPONENTS Kirigami)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(linkdeck src/main.cpp)

set(QML_FILES
    src/qml/Main.qml
    src/qml/Hub.qml
    src/qml/HomePage.qml
    src/qml/KeyboardPage.qml
    src/qml/KeyboardView.qml
    src/qml/KbLighting.qml
    src/qml/KbActuation.qml
    src/qml/KbPerformance.qml
    src/qml/KbDevice.qml
    src/qml/MousePage.qml
    src/qml/MouseView.qml
    src/qml/MsAssignments.qml
    src/qml/MsLighting.qml
    src/qml/MsDpi.qml
    src/qml/MsDevice.qml
    src/qml/ColorButton.qml
    src/qml/SectionMenu.qml
    src/qml/Panel.qml
    src/qml/ColorSwatches.qml
    src/qml/layout.js
)
# Keep the files in src/qml on disk but flat inside the module.
foreach(f ${QML_FILES})
    get_filename_component(name ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${name})
endforeach()
set_source_files_properties(src/qml/Hub.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(linkdeck
    URI linkdeck
    VERSION 1.0
    QML_FILES ${QML_FILES}
)

target_link_libraries(linkdeck PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Widgets
)

install(TARGETS linkdeck ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
install(FILES packaging/io.github.mattehrhart.linkdeck.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES packaging/io.github.mattehrhart.linkdeck.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})
install(FILES packaging/io.github.mattehrhart.linkdeck.svg DESTINATION ${KDE_INSTALL_FULL_ICONDIR}/hicolor/scalable/apps)
