cmake_minimum_required(VERSION 3.24)

project(
    openssl-cmake
    VERSION 0.2.0
    DESCRIPTION "Build OpenSSL in parallel within CMake"
    HOMEPAGE_URL "https://github.com/jimmy-park/openssl-cmake"
)

# Custom options
option(OPENSSL_PARALLEL_BUILD "Set to ON to enable parallel build" ON)
set(OPENSSL_TARGET_VERSION "3.0.7" CACHE STRING "Set OpenSSL version to download")
set(OPENSSL_TARGET_PLATFORM "" CACHE STRING "Set OpenSSL target platform")
set(OPENSSL_CONFIGURE_OPTIONS
    no-shared
    no-stdio
    no-tests
    no-ui-console
    no-comp
    no-deprecated
    CACHE STRING "Set OpenSSL configure options"
)

if(OPENSSL_PARALLEL_BUILD)
    include(ProcessorCount)
    ProcessorCount(NUMBER_OF_THREADS)

    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        list(APPEND OPENSSL_CONFIGURE_OPTIONS "/FS")
    endif()
endif()

if(OPENSSL_TARGET_PLATFORM STREQUAL "")
    message(FATAL_ERROR "Set OPENSSL_TARGET_PLATFORM")
endif()

# Validate OpenSSL version format
if(OPENSSL_TARGET_VERSION MATCHES "^3\.[0-9]\.+[0-9]$")
    set(OPENSSL_VERSION_TAG "openssl-${OPENSSL_TARGET_VERSION}")
elseif(OPENSSL_TARGET_VERSION MATCHES "^1\.1\.[0-1][a-z]$"
    OR OPENSSL_TARGET_VERSION MATCHES "^1\.0\.[0-2][a-z]$")
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

# Find vcvarsall.bat
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
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

    if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "AMD64")
        if(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64A")
            set(VCVARSALL_ARCH "x64")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32")
            set(VCVARSALL_ARCH "x64_x86")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64-ARM")
            set(VCVARSALL_ARCH "x64_arm64")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32-ARM")
            set(VCVARSALL_ARCH "x64_arm")
        endif()
    elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86")
        if(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64A")
            set(VCVARSALL_ARCH "x86_x64")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32")
            set(VCVARSALL_ARCH "x86")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64-ARM")
            set(VCVARSALL_ARCH "x86_arm64")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32-ARM")
            set(VCVARSALL_ARCH "x86_arm")
        endif()
    elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "ARM64")
        if(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64A")
            set(VCVARSALL_ARCH "arm64_x64")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32")
            set(VCVARSALL_ARCH "arm64_x86")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN64-ARM")
            set(VCVARSALL_ARCH "arm64")
        elseif(OPENSSL_TARGET_PLATFORM STREQUAL "VC-WIN32-ARM")
            set(VCVARSALL_ARCH "arm64_arm")
        endif()
    endif()

    if(NOT DEFINED VCVARSALL_ARCH)
        message(FATAL_ERROR "Couldn't select appropriate vcvarsall.bat argument")
    endif()
endif()

# Configure OpenSSL
function(configure_openssl)
    find_program(CONFIGURE_TOOL perl REQUIRED)
    find_file(
        OPENSSL_CONFIGDATA
        NAMES configdata.pm
        PATHS ${openssl_SOURCE_DIR}
        NO_CACHE
        NO_DEFAULT_PATH
    )

    if(NOT OPENSSL_CONFIGDATA STREQUAL "OPENSSL_CONFIGDATA-NOTFOUND")
        execute_process(
            COMMAND ${CONFIGURE_TOOL} ${OPENSSL_CONFIGDATA} --command-line
            WORKING_DIRECTORY ${openssl_SOURCE_DIR}
            OUTPUT_VARIABLE OPENSSL_PREV_COMMAND
            ECHO_ERROR_VARIABLE
            COMMAND_ERROR_IS_FATAL ANY
        )

        string(REPLACE "\n" ";" OPENSSL_PREV_COMMAND ${OPENSSL_PREV_COMMAND})
        list(FILTER OPENSSL_PREV_COMMAND INCLUDE REGEX "Configure")
        string(STRIP ${OPENSSL_PREV_COMMAND} OPENSSL_PREV_COMMAND)
        string(REPLACE " " ";" OPENSSL_PREV_COMMAND ${OPENSSL_PREV_COMMAND})
        list(SUBLIST OPENSSL_PREV_COMMAND 2 -1 OPENSSL_PREV_OPTIONS)
        message(STATUS "Found previous configure options : ${OPENSSL_PREV_OPTIONS}")

        set(OPENSSL_CURR_OPTIONS ${OPENSSL_TARGET_PLATFORM} ${OPENSSL_CONFIGURE_OPTIONS})

        foreach(PREV CURR IN ZIP_LISTS OPENSSL_PREV_OPTIONS OPENSSL_CURR_OPTIONS)
            if(NOT PREV STREQUAL CURR)
                set(RECONFIGURE ON)
                break()
            endif()
        endforeach()

        if(NOT RECONFIGURE)
            return()
        endif()

        if(DEFINED CACHE{BUILD_TOOL})
            message(STATUS "Clean all build results")
            execute_process(
                COMMAND ${BUILD_TOOL} clean
                WORKING_DIRECTORY ${openssl_SOURCE_DIR}
                OUTPUT_QUIET
                ERROR_QUIET
                COMMAND_ERROR_IS_FATAL ANY
            )
        endif()
    endif()

    execute_process(
        COMMAND ${CONFIGURE_TOOL} Configure LIST
        WORKING_DIRECTORY ${openssl_SOURCE_DIR}
        OUTPUT_VARIABLE OPENSSL_PLATFORM_LIST
        ECHO_ERROR_VARIABLE
        COMMAND_ERROR_IS_FATAL ANY
    )
    string(REPLACE "\n" ";" OPENSSL_PLATFORM_LIST ${OPENSSL_PLATFORM_LIST})

    if(NOT OPENSSL_TARGET_PLATFORM IN_LIST OPENSSL_PLATFORM_LIST)
        message(FATAL_ERROR "${OPENSSL_TARGET_PLATFORM} isn't supported")
    endif()

    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(OPENSSL_CONFIGURE_COMMAND ${VCVARSALL} ${VCVARSALL_ARCH} && ${CONFIGURE_TOOL} Configure ${OPENSSL_TARGET_PLATFORM} ${OPENSSL_CONFIGURE_OPTIONS})
    else()
        set(OPENSSL_CONFIGURE_COMMAND ${CONFIGURE_TOOL} Configure ${OPENSSL_TARGET_PLATFORM} ${OPENSSL_CONFIGURE_OPTIONS})
    endif()

    execute_process(
        COMMAND ${OPENSSL_CONFIGURE_COMMAND}
        WORKING_DIRECTORY ${openssl_SOURCE_DIR}
        ECHO_ERROR_VARIABLE
        COMMAND_ERROR_IS_FATAL ANY
    )
endfunction()

configure_openssl()

# Add custom command/target for parallel build
if(NUMBER_OF_THREADS GREATER 1)
    set(PARALLEL_OPTION "-j${NUMBER_OF_THREADS}")
endif()

if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    if(DEFINED PARALLEL_OPTION)
        find_program(BUILD_TOOL jom REQUIRED)
    else()
        cmake_path(GET CMAKE_C_COMPILER PARENT_PATH NMAKE_PATH)
        find_program(
            BUILD_TOOL
            NAMES nmake
            PATHS ${NMAKE_PATH}
            REQUIRED
            NO_CACHE
            NO_DEFAULT_PATH
        )
    endif()

    find_program(ASSEMBLER nasm REQUIRED)
    set(OPENSSL_BUILD_COMMAND ${VCVARSALL} ${VCVARSALL_ARCH} && ${BUILD_TOOL} ${PARALLEL_OPTION})
else()
    find_program(BUILD_TOOL make REQUIRED)
    set(OPENSSL_BUILD_COMMAND ${BUILD_TOOL} ${PARALLEL_OPTION})
endif()

execute_process(
    COMMAND ${OPENSSL_BUILD_COMMAND}
    WORKING_DIRECTORY ${openssl_SOURCE_DIR}
    ECHO_ERROR_VARIABLE
    COMMAND_ERROR_IS_FATAL ANY
)

if(PROJECT_IS_TOP_LEVEL)
    # add_subdirectory(apps)
endif()
