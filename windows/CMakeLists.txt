cmake_minimum_required(VERSION 3.14)
project(zonewapp LANGUAGES CXX)

set(BINARY_NAME "zonewapp")
set(APPLICATION_ID "com.hongshi.zonewapp")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Flutter library
set(FLUTTER_LIBRARY "${EPHEMERAL_DIR}/flutter_windows.dll")

# Flutter library headers
set(FLUTTER_LIBRARY_DIR "${EPHEMERAL_DIR}")
set(FLUTTER_ICU_DATA_FILE "${EPHEMERAL_DIR}/icudtl.dat")

# Application library
set(PROJECT_BUILD_DIR "${PROJECT_DIR}/build/")
set(AOT_LIBRARY "${PROJECT_BUILD_DIR}/windows/app.so")

# Copy the Flutter library
install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)

# Install bundled libraries
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
