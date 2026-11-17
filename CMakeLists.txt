cmake_minimum_required(VERSION 3.22)
project(halo VERSION 0.3.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Widgets DBus Network)
find_package(KF6 6.0 REQUIRED COMPONENTS Kirigami)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(halo src/main.cpp)

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
        src/qml/SysOverview.qml
        src/qml/SysChannels.qml
        src/qml/SysLighting.qml
        src/qml/SysLcd.qml
        src/qml/SysPorts.qml
        src/qml/SysWidgets.qml
        src/qml/FanCurves.qml
        src/qml/Skeleton.qml
        src/qml/PageSkeleton.qml
    src/qml/ColorButton.qml
    src/qml/EffectSettings.qml
    src/qml/Assignments.qml
    src/qml/KbAssignments.qml
    src/qml/DeviceStrip.qml
    src/qml/TypeTiles.qml
    src/qml/StatusLine.qml
    src/qml/DeviceGlyph.qml
    src/qml/OutlineView.qml
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

qt_add_qml_module(halo
    URI halo
    VERSION 1.0
    QML_FILES ${QML_FILES}
)

qt_add_resources(halo "devices"
    PREFIX "/devices"
    BASE src/devices
    FILES src/devices/k70-max.json src/devices/scimitar-elite.json src/devices/outlines.json
)

target_link_libraries(halo PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Widgets Qt6::DBus Qt6::Network
)

install(TARGETS halo ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
install(FILES packaging/io.github.mattehrhart.Halo.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES packaging/io.github.mattehrhart.Halo.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})
install(FILES packaging/io.github.mattehrhart.Halo.svg DESTINATION ${KDE_INSTALL_FULL_ICONDIR}/hicolor/scalable/apps)

# Tests: `ctest --test-dir build --output-on-failure`. Both run without a
# display; the smoke test opens every screen against tests/fakehub.
include(CTest)
if(BUILD_TESTING)
    find_package(Python3 COMPONENTS Interpreter)
    find_program(QMLTESTRUNNER NAMES qmltestrunner qmltestrunner6 qmltestrunner-qt6)
    if(QMLTESTRUNNER)
        add_test(NAME layout COMMAND ${QMLTESTRUNNER} -input ${CMAKE_SOURCE_DIR}/tests/tst_layout.qml)
        set_tests_properties(layout PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
    endif()
    if(Python3_FOUND)
        add_test(NAME screens COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/smoke.py $<TARGET_FILE:halo>)
        set_tests_properties(screens PROPERTIES TIMEOUT 900)
    endif()
endif()
