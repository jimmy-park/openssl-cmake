cmake_minimum_required(VERSION 3.24)

project(
    openssl-cmake
    VERSION 0.2.0
    DESCRIPTION "Build OpenSSL in parallel within CMake"
    HOMEPAGE_URL "https://github.com/jimmy-park/openssl-cmake"
    LANGUAGES C
)

include(ProcessorCount)
include(cmake/ConfigureOpenSSL.cmake)
include(cmake/FindVcvarsall.cmake)
include(cmake/GetCPM.cmake)

# Information of latest OpenSSL release
set(OPENSSL_LATEST_VERSION 3.0.7 CACHE INTERNAL "OpenSSL version of latest release")
set(OPENSSL_LATEST_SHA256 83049d042a260e696f62406ac5c08bf706fd84383f945cf21bd61e9ed95c396e CACHE INTERNAL "Hash of archived OpenSSL release")

# Custom options
option(OPENSSL_PARALLEL_BUILD "Enable parallel build" ON)
option(OPENSSL_CONFIGURE_VERBOSE "Print configure message to the standard output" OFF)
option(OPENSSL_USE_CCACHE "Use ccache if available" OFF)

if(NOT DEFINED OPENSSL_TARGET_VERSION)
    set(OPENSSL_TARGET_VERSION ${OPENSSL_LATEST_VERSION} CACHE INTERNAL "Set OpenSSL version to latest release")
endif()

if(NOT DEFINED OPENSSL_TARGET_PLATFORM)
    detect_target_platform(OPENSSL_TARGET_PLATFORM)
endif()

if(NOT DEFINED OPENSSL_CONFIGURE_OPTIONS)
    set(OPENSSL_CONFIGURE_OPTIONS
        no-tests
        CACHE INTERNAL "OpenSSL configure options except target platform and prefix"
    )
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

if(OPENSSL_TARGET_VERSION STREQUAL OPENSSL_LATEST_VERSION)
    set(CPM_HASH_OPTION URL_HASH SHA256=${OPENSSL_LATEST_SHA256})
endif()

# Download OpenSSL source
CPMAddPackage(
    NAME openssl
    URL https://www.openssl.org/source/openssl-${OPENSSL_TARGET_VERSION}.tar.gz
    ${CPM_HASH_OPTION}
    OVERRIDE_FIND_PACKAGE
)

# Clean build directory if version is different
if(NOT OPENSSL_TARGET_VERSION STREQUAL OPENSSL_TARGET_VERSION_OLD)
    set(OPENSSL_TARGET_VERSION_OLD ${OPENSSL_TARGET_VERSION} CACHE INTERNAL "Previously fetched OpenSSL version")

    if(IS_DIRECTORY ${openssl_BINARY_DIR})
        file(REMOVE_RECURSE ${openssl_BINARY_DIR})
        file(MAKE_DIRECTORY ${openssl_BINARY_DIR})
    endif()
endif()

# Run vcvarsall.bat with target architecture
find_vcvarsall(VCVARSALL)

if(NOT "${VCVARSALL}" STREQUAL "")
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

if(OPENSSL_PARALLEL_BUILD)
    ProcessorCount(NUMBER_OF_THREADS)
endif()

if(NUMBER_OF_THREADS GREATER 1)
    if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
        list(APPEND OPENSSL_CONFIGURE_OPTIONS "-FS")
    endif()

    list(APPEND OPENSSL_BUILD_OPTIONS "-j${NUMBER_OF_THREADS}")
endif()

# Configure OpenSSL
find_program(PERL perl REQUIRED)
set(OPENSSL_CONFIGURE_TOOL ${PERL})
set(OPENSSL_CONFIGURE_OUTPUT ${openssl_BINARY_DIR}/configdata.pm)
configure_openssl(
    COMMAND ${VCVARSALL_COMMAND}
    TOOL ${OPENSSL_CONFIGURE_TOOL}
    FILE ${openssl_SOURCE_DIR}/Configure
    BUILD_DIR ${openssl_BINARY_DIR}
    OPTIONS ${OPENSSL_CONFIGURE_OPTIONS}
    OUTPUT ${OPENSSL_CONFIGURE_OUTPUT}
    VERBOSE ${OPENSSL_CONFIGURE_VERBOSE}
)

# Parse configdata.pm
parse_configdata(${OPENSSL_CONFIGURE_OUTPUT} "options" FULL_CONFIGURE_OPTIONS)

if(NOT "no-shared" IN_LIST FULL_CONFIGURE_OPTIONS)
    set(OPENSSL_BUILD_SHARED_LIBS ON)
endif()

# Parse Makefile
find_file(
    OPENSSL_MAKEFILE
    NAMES makefile Makefile
    PATHS ${openssl_BINARY_DIR}
    REQUIRED
    NO_DEFAULT_PATH
)
parse_makefile(${OPENSSL_MAKEFILE} "INSTALL_LIBS" OPENSSL_STATIC_LIBS)
parse_makefile(${OPENSSL_MAKEFILE} "INSTALL_SHLIBS" OPENSSL_SHARED_LIBS)
list(TRANSFORM OPENSSL_STATIC_LIBS PREPEND "${openssl_BINARY_DIR}/")
list(TRANSFORM OPENSSL_SHARED_LIBS PREPEND "${openssl_BINARY_DIR}/")

foreach(LIBRARY IN LISTS OPENSSL_STATIC_LIBS)
    if(LIBRARY MATCHES "crypto")
        set(OPENSSL_STATIC_CRYPTO_LIBRARY ${LIBRARY})
    elseif(LIBRARY MATCHES "ssl")
        set(OPENSSL_STATIC_SSL_LIBRARY ${LIBRARY})
    endif()
endforeach()

foreach(LIBRARY IN LISTS OPENSSL_SHARED_LIBS)
    if(LIBRARY MATCHES "crypto")
        set(OPENSSL_SHARED_CRYPTO_LIBRARY ${LIBRARY})
    elseif(LIBRARY MATCHES "ssl")
        set(OPENSSL_SHARED_SSL_LIBRARY ${LIBRARY})
    endif()
endforeach()

if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND NOT OPENSSL_BUILD_SHARED_LIBS)
    find_package(Threads)

    if(CMAKE_THREAD_LIBS_INIT)
        list(APPEND OPENSSL_DEPENDENCIES ${CMAKE_THREAD_LIBS_INIT})
    endif()

    list(APPEND OPENSSL_DEPENDENCIES ${CMAKE_DL_LIBS})
endif()

# Modify Makefile
if(OPENSSL_USE_CCACHE)
    find_program(CCACHE ccache)

    if(CCACHE)
        file(READ ${OPENSSL_MAKEFILE} MAKEFILE)

        if(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
            string(REGEX REPLACE "CC=[^\n]*" "CC=ccache cl" MAKEFILE "${MAKEFILE}")
            string(REPLACE "/Zi /Fdossl_static.pdb " "" MAKEFILE "${MAKEFILE}")
        else()
            parse_makefile(${OPENSSL_MAKEFILE} "CC" OPENSSL_C_COMPILER)
            string(REPLACE ";" " " OPENSSL_C_COMPILER "${OPENSSL_C_COMPILER}")
            string(REGEX REPLACE "\nCC=[^\n]*" "\nCC=${CCACHE} ${OPENSSL_C_COMPILER}" MAKEFILE "${MAKEFILE}")
        endif()

        file(WRITE ${OPENSSL_MAKEFILE} "${MAKEFILE}")
    endif()
endif()

# Provide result variables of FindOpenSSL module
set(OPENSSL_FOUND ON CACHE BOOL "Override FindOpenSSL variables" FORCE)
set(OPENSSL_INCLUDE_DIR ${openssl_SOURCE_DIR}/include ${openssl_BINARY_DIR}/include CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_CRYPTO_LIBRARY ${OPENSSL_STATIC_CRYPTO_LIBRARY} ${OPENSSL_SHARED_CRYPTO_LIBRARY} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_CRYPTO_LIBRARIES ${OPENSSL_CRYPTO_LIBRARY} ${OPENSSL_DEPENDENCIES} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_SSL_LIBRARY ${OPENSSL_STATIC_SSL_LIBRARY} ${OPENSSL_SHARED_SSL_LIBRARY} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_SSL_LIBRARIES ${OPENSSL_SSL_LIBRARY} ${OPENSSL_DEPENDENCIES} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_LIBRARIES ${OPENSSL_CRYPTO_LIBRARY} ${OPENSSL_SSL_LIBRARY} ${OPENSSL_DEPENDENCIES} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_VERSION ${OPENSSL_TARGET_VERSION} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_APPLINK_SOURCE ${openssl_SOURCE_DIR}/ms/applink.c CACHE STRING "Override FindOpenSSL variables" FORCE)

# Create same targets as FindOpenSSL module
add_library(OpenSSL::applink INTERFACE IMPORTED GLOBAL)

if(OPENSSL_BUILD_SHARED_LIBS)
    add_library(OpenSSL::Crypto SHARED IMPORTED GLOBAL)
    add_library(OpenSSL::SSL SHARED IMPORTED GLOBAL)
    set_target_properties(OpenSSL::Crypto PROPERTIES
        IMPORTED_LOCATION ${OPENSSL_SHARED_CRYPTO_LIBRARY}
    )
    set_target_properties(OpenSSL::SSL PROPERTIES
        IMPORTED_LOCATION ${OPENSSL_SHARED_SSL_LIBRARY}
    )

    if(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
        set_target_properties(OpenSSL::Crypto PROPERTIES
            IMPORTED_IMPLIB ${OPENSSL_STATIC_CRYPTO_LIBRARY}
        )
        set_target_properties(OpenSSL::SSL PROPERTIES
            IMPORTED_IMPLIB ${OPENSSL_STATIC_SSL_LIBRARY}
        )
        set_target_properties(OpenSSL::applink PROPERTIES
            INTERFACE_SOURCES ${OPENSSL_APPLINK_SOURCE}
        )
    endif()
else()
    add_library(OpenSSL::Crypto STATIC IMPORTED GLOBAL)
    add_library(OpenSSL::SSL STATIC IMPORTED GLOBAL)
    set_target_properties(OpenSSL::Crypto PROPERTIES
        IMPORTED_LOCATION ${OPENSSL_STATIC_CRYPTO_LIBRARY}
    )
    set_target_properties(OpenSSL::SSL PROPERTIES
        IMPORTED_LOCATION ${OPENSSL_STATIC_SSL_LIBRARY}
    )

    if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
        set(OPENSSL_LINK_DEPENDENCIES ws2_32 crypt32)
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        if(Threads_FOUND)
            set(OPENSSL_LINK_DEPENDENCIES Threads::Threads)
        endif()

        list(APPEND OPENSSL_LINK_DEPENDENCIES ${CMAKE_DL_LIBS})
    endif()
endif()

set_target_properties(OpenSSL::Crypto PROPERTIES
    IMPORTED_LINK_INTERFACE_LANGUAGES C
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "${OPENSSL_LINK_DEPENDENCIES}"
)
set_target_properties(OpenSSL::SSL PROPERTIES
    IMPORTED_LINK_INTERFACE_LANGUAGES C
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "${OPENSSL_LINK_DEPENDENCIES};OpenSSL::Crypto"
)

# Find build tool
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
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
else()
    find_program(MAKE make REQUIRED)
    set(OPENSSL_BUILD_TOOL ${MAKE})
endif()

# Add a custom target to build OpenSSL
set(OPENSSL_BUILD_COMMAND ${VCVARSALL_COMMAND} ${OPENSSL_BUILD_TOOL} ${OPENSSL_BUILD_OPTIONS} build_libs)
set(OPENSSL_BUILD_OUTPUT
    ${OPENSSL_STATIC_CRYPTO_LIBRARY}
    ${OPENSSL_STATIC_SSL_LIBRARY}
    ${OPENSSL_SHARED_CRYPTO_LIBRARY}
    ${OPENSSL_SHARED_SSL_LIBRARY}
)
add_custom_command(
    OUTPUT ${OPENSSL_BUILD_OUTPUT}
    COMMAND ${OPENSSL_BUILD_COMMAND}
    WORKING_DIRECTORY ${openssl_BINARY_DIR}
)
add_custom_target(openssl-build DEPENDS ${OPENSSL_BUILD_OUTPUT})
add_dependencies(OpenSSL::Crypto openssl-build)
add_dependencies(OpenSSL::SSL openssl-build)

# Install OpenSSL
set(OPENSSL_INSTALL_COMMAND ${OPENSSL_BUILD_TOOL} install_dev)

if(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
    list(APPEND OPENSSL_INSTALL_COMMAND /NOLOGO)
endif()

install(
    CODE "execute_process(
            COMMAND ${OPENSSL_INSTALL_COMMAND}
            WORKING_DIRECTORY ${openssl_BINARY_DIR}
            OUTPUT_QUIET
        )"
)

if(PROJECT_IS_TOP_LEVEL)
    add_subdirectory(apps)
endif()