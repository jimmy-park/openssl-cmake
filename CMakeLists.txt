cmake_minimum_required(VERSION 3.24)

project(
    openssl-cmake
    VERSION 0.2.0
    DESCRIPTION "Build OpenSSL in parallel within CMake"
    HOMEPAGE_URL "https://github.com/jimmy-park/openssl-cmake"
    LANGUAGES C
)

include(FetchContent)
include(ProcessorCount)
include(cmake/ConfigureOpenSSL.cmake)
include(cmake/FindVcvarsall.cmake)

# Custom options
option(OPENSSL_PARALLEL_BUILD "Enable parallel build" ON)
option(OPENSSL_VERBOSE "Print configure/build message to the standard output" OFF)

if(NOT DEFINED OPENSSL_TARGET_VERSION)
    set(OPENSSL_TARGET_VERSION "3.0.7" CACHE INTERNAL "Set OpenSSL version to latest release")
endif()

if(NOT DEFINED OPENSSL_TARGET_PLATFORM)
    message(FATAL_ERROR "Set OPENSSL_TARGET_PLATFORM")
endif()

if(NOT DEFINED OPENSSL_CONFIGURE_OPTIONS)
    set(OPENSSL_CONFIGURE_OPTIONS
        no-shared
        no-stdio
        no-tests
        no-ui-console
        no-comp
        no-deprecated
        CACHE INTERNAL "OpenSSL configure options except target platform and prefix"
    )
endif()

if(OPENSSL_PARALLEL_BUILD)
    ProcessorCount(NUMBER_OF_THREADS)
endif()

# Validate OpenSSL version
if(OPENSSL_TARGET_VERSION MATCHES "^3\.[0-9]\.[0-9]+$"
    OR OPENSSL_TARGET_VERSION MATCHES "^1\.1\.[0-1][a-z]$")
    if(OPENSSL_TARGET_VERSION STRLESS "1.1.0h")
        message(FATAL_ERROR "OpenSSL versions below 1.1.0h aren't supported")
    endif()
else()
    message(FATAL_ERROR "Invalid OpenSSL version format")
endif()

# Download OpenSSL source
message(STATUS "Fetching OpenSSL ${OPENSSL_TARGET_VERSION}")
FetchContent_Declare(
    openssl
    URL https://www.openssl.org/source/openssl-${OPENSSL_TARGET_VERSION}.tar.gz
    OVERRIDE_FIND_PACKAGE
)
FetchContent_MakeAvailable(openssl)

# Clean build directory if version is different
if(NOT OPENSSL_TARGET_VERSION STREQUAL OPENSSL_TARGET_VERSION_OLD)
    set(OPENSSL_TARGET_VERSION_OLD ${OPENSSL_TARGET_VERSION} CACHE INTERNAL "Previously fetched OpenSSL version")
    file(REMOVE_RECURSE ${openssl_BINARY_DIR})
    file(MAKE_DIRECTORY ${openssl_BINARY_DIR})
endif()

# Find configure tool
find_program(OPENSSL_CONFIGURE_TOOL perl REQUIRED)

# Run vcvarsall.bat with target architecture
find_vcvarsall(VCVARSALL)

if(NOT VCVARSALL STREQUAL "")
    if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86")
        if(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32")
            set(VCVARSALL_ARCH "x86")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64A")
            set(VCVARSALL_ARCH "x86_x64")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32-ARM")
            set(VCVARSALL_ARCH "x86_arm")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64-ARM")
            set(VCVARSALL_ARCH "x86_arm64")
        endif()
    elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "AMD64")
        if(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32")
            set(VCVARSALL_ARCH "x64_x86")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64A")
            set(VCVARSALL_ARCH "x64")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32-ARM")
            set(VCVARSALL_ARCH "x64_arm")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64-ARM")
            set(VCVARSALL_ARCH "x64_arm64")
        endif()
    elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "ARM64")
        if(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32")
            set(VCVARSALL_ARCH "arm64_x86")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64A")
            set(VCVARSALL_ARCH "arm64_x64")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32-ARM")
            set(VCVARSALL_ARCH "arm64_arm")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64-ARM")
            set(VCVARSALL_ARCH "arm64")
        endif()
    endif()

    if(NOT DEFINED VCVARSALL_ARCH)
        message(FATAL_ERROR "Couldn't select appropriate vcvarsall.bat argument")
    endif()

    set(VCVARSALL_COMMAND ${VCVARSALL} ${VCVARSALL_ARCH} &&)
endif()

# Modify configure/build options
set(OPENSSL_INSTALL_DIR ${CMAKE_INSTALL_PREFIX}/OpenSSL-${OPENSSL_TARGET_VERSION})
list(FILTER OPENSSL_CONFIGURE_OPTIONS EXCLUDE REGEX "--prefix")
list(APPEND OPENSSL_CONFIGURE_OPTIONS "--prefix=${OPENSSL_INSTALL_DIR}")
list(PREPEND OPENSSL_CONFIGURE_OPTIONS ${OPENSSL_TARGET_PLATFORM})

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    if(NUMBER_OF_THREADS GREATER 1)
        list(APPEND OPENSSL_CONFIGURE_OPTIONS "-FS")
    endif()

    if(NOT OPENSSL_VERBOSE)
        list(APPEND OPENSSL_BUILD_OPTIONS "/NOLOGO")
    endif()
endif()

if(NUMBER_OF_THREADS GREATER 1)
    list(APPEND OPENSSL_BUILD_OPTIONS "-j${NUMBER_OF_THREADS}")
endif()

# Configure OpenSSL
set(OPENSSL_CONFIGURE_OUTPUT ${openssl_BINARY_DIR}/configdata.pm)
configure_openssl(
    COMMAND ${VCVARSALL_COMMAND}
    TOOL ${OPENSSL_CONFIGURE_TOOL}
    FILE ${openssl_SOURCE_DIR}/Configure
    BUILD_DIR ${openssl_BINARY_DIR}
    OPTIONS ${OPENSSL_CONFIGURE_OPTIONS}
    OUTPUT ${OPENSSL_CONFIGURE_OUTPUT}
    VERBOSE ${OPENSSL_VERBOSE}
)

# Find build tool
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    if(NUMBER_OF_THREADS GREATER 1)
        find_program(JOM jom REQUIRED)
        set(OPENSSL_BUILD_TOOL ${JOM})
    else()
        cmake_path(GET CMAKE_C_COMPILER PARENT_PATH NMAKE_PATH)
        find_program(
            NMAKE
            NAMES nmake
            PATHS ${NMAKE_PATH}
            REQUIRED
            NO_DEFAULT_PATH
        )
        set(OPENSSL_BUILD_TOOL ${NMAKE})
    endif()

    parse_configdata(${OPENSSL_CONFIGURE_OUTPUT} "options" FULL_OPTIONS)

    if(NOT "no-asm" IN_LIST FULL_OPTIONS)
        find_program(OPENSSL_ASSEMBLER nasm REQUIRED)
        message(STATUS "${OPENSSL_ASSEMBLER}")
    endif()
else()
    find_program(OPENSSL_BUILD_TOOL make REQUIRED)
endif()


# Build OpenSSL
set(OPENSSL_BUILD_COMMAND ${VCVARSALL_COMMAND} ${OPENSSL_BUILD_TOOL} ${OPENSSL_BUILD_OPTIONS})
set(OPENSSL_INSTALL_COMMAND ${OPENSSL_BUILD_TOOL} install_sw)
set(OPENSSL_UNINSTALL_COMMAND ${CMAKE_COMMAND} -E rm -rf ${OPENSSL_INSTALL_DIR})
set(SLEEP_COMMAND ${CMAKE_COMMAND} -E sleep 1)
set(TRY_INSTALL_COUNT 10)

if(OPENSSL_VERBOSE)
    execute_process(
        COMMAND ${OPENSSL_BUILD_COMMAND}
        WORKING_DIRECTORY ${openssl_BINARY_DIR}
        COMMAND_ERROR_IS_FATAL ANY
    )
    execute_process(
        COMMAND ${OPENSSL_UNINSTALL_COMMAND}
        COMMAND_ERROR_IS_FATAL ANY
    )

    set(INSTALL_COUNT 0)

    while(TRUE)
        execute_process(
            COMMAND ${OPENSSL_INSTALL_COMMAND}
            WORKING_DIRECTORY ${openssl_BINARY_DIR}
            RESULT_VARIABLE INSTALL_RESULT
        )

        if(INSTALL_RESULT EQUAL 0 OR INSTALL_COUNT EQUAL TRY_INSTALL_COUNT)
            break()
        endif()

        execute_process(
            COMMAND ${SLEEP_COMMAND}
            COMMAND_ERROR_IS_FATAL ANY
        )
        math(EXPR INSTALL_COUNT "${INSTALL_COUNT} + 1")
        message(STATUS "Failed to install. Try install again... (${INSTALL_COUNT} / ${TRY_INSTALL_COUNT})")
    endwhile()
else()
    message(STATUS "Build OpenSSL")
    execute_process(
        COMMAND ${OPENSSL_BUILD_COMMAND}
        WORKING_DIRECTORY ${openssl_BINARY_DIR}
        OUTPUT_QUIET
        ERROR_QUIET # Suppress perl warnings
        COMMAND_ERROR_IS_FATAL ANY
    )
    message(STATUS "Uninstall OpenSSL")
    execute_process(
        COMMAND ${OPENSSL_UNINSTALL_COMMAND}
        OUTPUT_QUIET
        COMMAND_ERROR_IS_FATAL ANY
    )
    message(STATUS "Install OpenSSL")
    set(INSTALL_COUNT 0)

    # Installation may fail due to permission denial
    while(TRUE)
        execute_process(
            COMMAND ${OPENSSL_INSTALL_COMMAND}
            WORKING_DIRECTORY ${openssl_BINARY_DIR}
            RESULT_VARIABLE INSTALL_RESULT
            OUTPUT_QUIET
            ERROR_QUIET
        )

        if(INSTALL_RESULT EQUAL 0 OR INSTALL_COUNT EQUAL TRY_INSTALL_COUNT)
            break()
        endif()

        execute_process(
            COMMAND ${SLEEP_COMMAND}
            COMMAND_ERROR_IS_FATAL ANY
        )
        math(EXPR INSTALL_COUNT "${INSTALL_COUNT} + 1")
    endwhile()
endif()

if(PROJECT_IS_TOP_LEVEL)
    # add_subdirectory(apps)
endif()