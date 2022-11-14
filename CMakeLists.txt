cmake_minimum_required(VERSION 3.24)

project(
    openssl-cmake
    VERSION 0.2.0
    DESCRIPTION "Build OpenSSL in parallel within CMake"
    HOMEPAGE_URL "https://github.com/jimmy-park/openssl-cmake"
    LANGUAGES C
)

# Custom options
option(OPENSSL_PARALLEL_BUILD "Enable parallel build" ON)
option(OPENSSL_VERBOSE "Print configure/build message to the standard output" OFF)

if(NOT DEFINED OPENSSL_TARGET_VERSION)
    set(OPENSSL_TARGET_VERSION "3.0.7" CACHE INTERNAL "Set OpenSSL version to latest release")
elseif(OPENSSL_TARGET_VERSION STRLESS "1.1.0h")
    message(FATAL_ERROR "OpenSSL versions below 1.1.0h aren't supported")
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

# Validate OpenSSL version format
if(OPENSSL_TARGET_VERSION MATCHES "^3\.[0-9]\.+[0-9]$")
    set(OPENSSL_VERSION_TAG "openssl-${OPENSSL_TARGET_VERSION}")
elseif(OPENSSL_TARGET_VERSION MATCHES "^1\.1\.[0-1][a-z]$")
    set(OPENSSL_VERSION_TAG "OpenSSL_${OPENSSL_TARGET_VERSION}")
    string(REPLACE "." "_" OPENSSL_VERSION_TAG ${OPENSSL_VERSION_TAG})
else()
    message(FATAL_ERROR "Invalid OpenSSL version")
endif()

# Download OpenSSL source
message(STATUS "Fetching OpenSSL ${OPENSSL_TARGET_VERSION}")
include(FetchContent)
FetchContent_Declare(
    openssl
    URL https://github.com/openssl/openssl/archive/${OPENSSL_VERSION_TAG}.zip
    OVERRIDE_FIND_PACKAGE
)
FetchContent_MakeAvailable(openssl)

# clean build directory if version is different
function(clean_build_dir)
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E rm -rf ${openssl_BINARY_DIR}
        COMMAND_ERROR_IS_FATAL ANY
    )
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E make_directory ${openssl_BINARY_DIR}
        COMMAND_ERROR_IS_FATAL ANY
    )
endfunction()

if(NOT OPENSSL_TARGET_VERSION STREQUAL OPENSSL_TARGET_VERSION_OLD)
    clean_build_dir()
endif()

set(OPENSSL_TARGET_VERSION_OLD ${OPENSSL_TARGET_VERSION} CACHE INTERNAL "")

# Find configure/build tool
find_program(OPENSSL_CONFIGURE_TOOL perl REQUIRED)

if(OPENSSL_PARALLEL_BUILD)
    include(ProcessorCount)
    ProcessorCount(NUMBER_OF_THREADS)
endif()

if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    if(NUMBER_OF_THREADS GREATER 1)
        find_program(OPENSSL_BUILD_TOOL jom REQUIRED)
    else()
        cmake_path(GET CMAKE_C_COMPILER PARENT_PATH NMAKE_PATH)
        find_program(
            OPENSSL_BUILD_TOOL
            NAMES nmake
            PATHS ${NMAKE_PATH}
            REQUIRED
            NO_DEFAULT_PATH
        )
    endif()

    set(OPENSSL_HAS_ASM ON)

    foreach(OPTION IN LISTS OPENSSL_CONFIGURE_OPTIONS)
        if(OPTION STREQUAL "no-asm")
            set(OPENSSL_HAS_ASM OFF)
            break()
        endif()
    endforeach()

    if(OPENSSL_HAS_ASM)
        find_program(OPENSSL_ASSEMBLER nasm REQUIRED)
    endif()
else()
    find_program(OPENSSL_BUILD_TOOL make REQUIRED)
endif()

# Find vcvarsall.bat using CMAKE_C_COMPILER
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    if(NOT CMAKE_C_COMPILER_ID STREQUAL "MSVC")
        message(FATAL_ERROR "Use MSVC compiler in Windows")
    endif()

    cmake_path(GET CMAKE_C_COMPILER PARENT_PATH VS_PATH)

    while(TRUE)
        cmake_path(GET VS_PATH PARENT_PATH VS_PATH)
        cmake_path(GET VS_PATH FILENAME VS_PATH_LAST)

        if(VS_PATH_LAST STREQUAL "VC")
            break()
        elseif(VS_PATH_LAST STREQUAL "")
            message(FATAL_ERROR "Couldn't find path of vcvarsall.bat")
        endif()
    endwhile()

    cmake_path(APPEND VS_PATH Auxiliary Build OUTPUT_VARIABLE VS_PATH)
    find_program(
        VCVARSALL
        NAMES vcvarsall.bat
        PATHS ${VS_PATH}
        REQUIRED
        NO_DEFAULT_PATH
    )

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
set(OPENSSL_INSTALL_DIR ${openssl_BINARY_DIR}/install)
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
function(configure_openssl)
    message(STATUS "Curruent configure options : ${OPENSSL_CONFIGURE_OPTIONS}")

    # Find previous configure results
    find_file(
        OPENSSL_CONFIGDATA
        NAMES configdata.pm
        PATHS ${openssl_BINARY_DIR}
        NO_CACHE
        NO_DEFAULT_PATH
    )

    if(NOT OPENSSL_CONFIGDATA STREQUAL "OPENSSL_CONFIGDATA-NOTFOUND")
        execute_process(
            COMMAND ${OPENSSL_CONFIGURE_TOOL} ${OPENSSL_CONFIGDATA} --command-line
            WORKING_DIRECTORY ${openssl_BINARY_DIR}
            RESULT_VARIABLE OPENSSL_CONFIGDATA_RESULT
            OUTPUT_VARIABLE OPENSSL_CONFIGDATA_OUTPUT
            ERROR_QUIET
        )

        if(OPENSSL_CONFIGDATA_RESULT EQUAL 0)
            # Command string manipulation
            string(REPLACE "\n" ";" OPENSSL_CONFIGDATA_OUTPUT ${OPENSSL_CONFIGDATA_OUTPUT})
            list(FILTER OPENSSL_CONFIGDATA_OUTPUT INCLUDE REGEX "Configure")
            string(STRIP ${OPENSSL_CONFIGDATA_OUTPUT} OPENSSL_CONFIGDATA_OUTPUT)
            string(REPLACE " " ";" OPENSSL_CONFIGURE_OPTIONS_OLD ${OPENSSL_CONFIGDATA_OUTPUT})
            list(FILTER OPENSSL_CONFIGURE_OPTIONS_OLD EXCLUDE REGEX "Configure|perl")
            message(STATUS "Previous configure options : ${OPENSSL_CONFIGURE_OPTIONS_OLD}")

            if(OPENSSL_CONFIGURE_OPTIONS STREQUAL OPENSSL_CONFIGURE_OPTIONS_OLD)
                message(STATUS "Found previous configure results. Don't perform configuration")
                return()
            endif()
        endif()

        message(STATUS "Configure options are changed. Clean all build results")
        clean_build_dir()
    endif()

    execute_process(
        COMMAND ${OPENSSL_CONFIGURE_TOOL} ${openssl_SOURCE_DIR}/Configure LIST
        WORKING_DIRECTORY ${openssl_BINARY_DIR}
        OUTPUT_VARIABLE OPENSSL_PLATFORM_LIST
        COMMAND_ERROR_IS_FATAL ANY
    )
    string(REPLACE "\n" ";" OPENSSL_PLATFORM_LIST ${OPENSSL_PLATFORM_LIST})

    if(NOT OPENSSL_TARGET_PLATFORM IN_LIST OPENSSL_PLATFORM_LIST)
        message(FATAL_ERROR "${OPENSSL_TARGET_PLATFORM} isn't supported")
    endif()

    # Set environment variables before configuration
    set(ENV{PERL} ${OPENSSL_CONFIGURE_TOOL})

    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        set(ENV{RANLIB} "ranlib -c -no_warning_for_no_symbols")
    endif()

    message(STATUS "Configure OpenSSL")
    set(OPENSSL_CONFIGURE_COMMAND
        ${VCVARSALL_COMMAND}
        ${OPENSSL_CONFIGURE_TOOL}
        ${openssl_SOURCE_DIR}/Configure
        ${OPENSSL_CONFIGURE_OPTIONS}
    )

    if(OPENSSL_VERBOSE)
        execute_process(
            COMMAND ${OPENSSL_CONFIGURE_COMMAND}
            WORKING_DIRECTORY ${openssl_BINARY_DIR}
            COMMAND_ERROR_IS_FATAL ANY
        )
    else()
        execute_process(
            COMMAND ${OPENSSL_CONFIGURE_COMMAND}
            WORKING_DIRECTORY ${openssl_BINARY_DIR}
            OUTPUT_QUIET
            COMMAND_ERROR_IS_FATAL ANY
        )
    endif()
endfunction()

configure_openssl()

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