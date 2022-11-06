cmake_minimum_required(VERSION 3.24)

project(openssl-cmake)

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
    CACHE STRING "Set OpenSSL configure options" FORCE
)

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

    execute_process(
        COMMAND ${CONFIGURE_TOOL} Configure ${OPENSSL_TARGET_PLATFORM} ${OPENSSL_CONFIGURE_OPTIONS}
        WORKING_DIRECTORY ${openssl_SOURCE_DIR}
        ECHO_ERROR_VARIABLE
        COMMAND_ERROR_IS_FATAL ANY
    )
endfunction()

configure_openssl()

if(PROJECT_IS_TOP_LEVEL)
    # add_subdirectory(apps)
endif()
