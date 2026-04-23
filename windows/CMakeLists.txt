cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "zoom_video_sdk_flutter")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "zoom_video_sdk_flutter_plugin")

# Zoom Video SDK paths
set(ZOOM_SDK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/zoom_sdk")
set(ZOOM_SDK_INCLUDE_DIR "${ZOOM_SDK_DIR}/include")
set(ZOOM_SDK_LIB_DIR "${ZOOM_SDK_DIR}/lib")
set(ZOOM_SDK_BIN_DIR "${ZOOM_SDK_DIR}/bin")

list(APPEND PLUGIN_SOURCES
  "zoom_video_sdk_flutter_plugin.cpp"
  "zoom_video_sdk_flutter_plugin.h"
  "zoom_event_stream_handler.cpp"
  "zoom_event_stream_handler.h"
  "zoom_video_texture_renderer.cpp"
  "zoom_video_texture_renderer.h"
  "zoom_serializer.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/zoom_video_sdk_flutter/zoom_video_sdk_flutter_plugin_c_api.h"
  "zoom_video_sdk_flutter_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${ZOOM_SDK_INCLUDE_DIR}")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
target_link_libraries(${PLUGIN_NAME} PRIVATE "${ZOOM_SDK_LIB_DIR}/videosdk.lib")

# Bundle ALL Zoom SDK runtime files — not just DLLs. Screen sharing
# spawns zCSVCptHost.exe at runtime; without the .exe files (and
# crashrpt_lang.ini for the crash reporter), startShareScreen /
# startShareView fail with ZoomVideoSDKErrors_Internal_Error (2).
file(GLOB ZOOM_SDK_RUNTIME_FILES
  "${ZOOM_SDK_BIN_DIR}/*.dll"
  "${ZOOM_SDK_BIN_DIR}/*.exe"
  "${ZOOM_SDK_BIN_DIR}/*.ini"
)
set(zoom_video_sdk_flutter_bundled_libraries
  ${ZOOM_SDK_RUNTIME_FILES}
  PARENT_SCOPE
)

# === Tests ===
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.15.2.zip
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

add_executable(${TEST_RUNNER}
  test/zoom_video_sdk_flutter_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_include_directories(${TEST_RUNNER} PRIVATE "${ZOOM_SDK_INCLUDE_DIR}")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
target_link_libraries(${TEST_RUNNER} PRIVATE "${ZOOM_SDK_LIB_DIR}/videosdk.lib")
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
