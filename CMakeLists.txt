cmake_minimum_required(VERSION 3.25)

project(
    openssl-cmake
    VERSION 0.7.1
    DESCRIPTION "Build OpenSSL in parallel within CMake"
    HOMEPAGE_URL "https://github.com/jimmy-park/openssl-cmake"
    LANGUAGES C
)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE NEVER)

include(FetchContent)
include(ProcessorCount)
include(cmake/ConfigureOpenSSL.cmake)
include(cmake/DetectTargetPlatform.cmake)
include(cmake/FindVcvarsall.cmake)
include(cmake/GetCPM.cmake)

# Information of latest OpenSSL release
set(OPENSSL_LATEST_VERSION 3.1.1 CACHE INTERNAL "OpenSSL version of latest release")
set(OPENSSL_LATEST_SHA256 b3aa61334233b852b63ddb048df181177c2c659eb9d4376008118f9c08d07674 CACHE INTERNAL "Hash of archived OpenSSL release")

# Custom options
option(OPENSSL_BUILD_VERBOSE "Enable verbose output from build" OFF)
option(OPENSSL_CONFIGURE_VERBOSE "Enable verbose output from configuration" OFF)
option(OPENSSL_ENABLE_PARALLEL "Enable parallel build and test" ON)
option(OPENSSL_INSTALL "Install OpenSSL components to the <prefix> directory" OFF)
option(OPENSSL_INSTALL_CERT "Install cert.pem to the <openssldir> directory" OFF)
option(OPENSSL_TEST "Enable testing and build OpenSSL self tests" OFF)
option(OPENSSL_USE_CCACHE "Use ccache if available" ON)

if(NOT DEFINED OPENSSL_BUILD_TARGET)
    # Build only libraries by default
    set(OPENSSL_BUILD_TARGET build_libs)
endif()

if(NOT DEFINED OPENSSL_INSTALL_TARGET)
    # Install only libraries by default
    set(OPENSSL_INSTALL_TARGET install_dev)
endif()

if(NOT DEFINED OPENSSL_TARGET_VERSION)
    set(OPENSSL_TARGET_VERSION ${OPENSSL_LATEST_VERSION})
endif()

if(NOT DEFINED OPENSSL_TARGET_PLATFORM)
    detect_target_platform(OPENSSL_TARGET_PLATFORM)
endif()

# Validate OpenSSL version
if(NOT OPENSSL_TARGET_VERSION MATCHES "(^3\.[0-9]\.[0-9]+$)|(^1\.1\.1[a-z]$)")
    message(FATAL_ERROR "OpenSSL ${OPENSSL_TARGET_VERSION} isn't supported")
endif()

if(OPENSSL_TARGET_VERSION STREQUAL OPENSSL_LATEST_VERSION)
    set(CPM_HASH_OPTION URL_HASH SHA256=${OPENSSL_LATEST_SHA256})
else()
    set(CPM_HASH_OPTION "")
endif()

# Download OpenSSL source
CPMAddPackage(
    NAME openssl-source
    URL https://www.openssl.org/source/openssl-${OPENSSL_TARGET_VERSION}.tar.gz
    DOWNLOAD_ONLY ON
    ${CPM_HASH_OPTION}
)
FetchContent_Declare(
    OpenSSL
    SOURCE_DIR ${openssl-source_SOURCE_DIR}
    BINARY_DIR ${openssl-source_BINARY_DIR}
    OVERRIDE_FIND_PACKAGE
)
FetchContent_MakeAvailable(OpenSSL)

# Apply a patch
if(EXISTS "${OPENSSL_PATCH}" AND NOT IS_DIRECTORY "${OPENSSL_PATCH}")
    execute_process(
        COMMAND git init
        WORKING_DIRECTORY ${openssl_SOURCE_DIR}
        OUTPUT_QUIET
        ERROR_QUIET
    )
    execute_process(
        COMMAND git apply ${OPENSSL_PATCH}
        WORKING_DIRECTORY ${openssl_SOURCE_DIR}
        OUTPUT_QUIET
        ERROR_QUIET
    )
endif()

# Clean build directory if version is different
if(NOT OPENSSL_TARGET_VERSION STREQUAL OPENSSL_TARGET_VERSION_OLD)
    set(OPENSSL_TARGET_VERSION_OLD ${OPENSSL_TARGET_VERSION} CACHE INTERNAL "Previously fetched OpenSSL version")

    if(IS_DIRECTORY ${openssl_BINARY_DIR})
        file(REMOVE_RECURSE ${openssl_BINARY_DIR})
        file(MAKE_DIRECTORY ${openssl_BINARY_DIR})
    endif()
endif()

# Run vcvarsall.bat with target architecture
set_vcvarsall_command(VCVARSALL_COMMAND)

# Set environment variables for Android NDK
if(ANDROID)
    set(ENV{PATH} ${ANDROID_TOOLCHAIN_ROOT}/bin:$ENV{PATH})
    set(ENV{ANDROID_NDK_ROOT} ${CMAKE_ANDROID_NDK})
endif()

# Modify configure/build options
if(OPENSSL_TEST AND NOT CMAKE_CROSSCOMPILING)
    set(OPENSSL_BUILD_TARGET "")
else()
    list(APPEND OPENSSL_CONFIGURE_OPTIONS no-tests)
endif()

if(NOT OPENSSL_BUILD_VERBOSE)
    if(MSVC)
        list(APPEND OPENSSL_BUILD_OPTIONS /NOLOGO /S)

        # LNK4099 : PDB 'filename' was not found with 'object/library' or at 'path'
        set(ENV{LDFLAGS} "/NOLOGO /DEBUG /IGNORE:4099")
    else()
        list(APPEND OPENSSL_BUILD_OPTIONS -s)
    endif()
endif()

if(OPENSSL_ENABLE_PARALLEL)
    ProcessorCount(NUMBER_OF_THREADS)
endif()

if(NUMBER_OF_THREADS GREATER 1)
    if(MSVC)
        list(APPEND OPENSSL_CONFIGURE_OPTIONS /FS)
        list(APPEND OPENSSL_BUILD_OPTIONS /J ${NUMBER_OF_THREADS})
    else()
        list(APPEND OPENSSL_BUILD_OPTIONS -j ${NUMBER_OF_THREADS})
    endif()
endif()

if(OPENSSL_USE_STATIC_LIBS)
    list(APPEND OPENSSL_CONFIGURE_OPTIONS no-shared)
endif()

list(SORT OPENSSL_CONFIGURE_OPTIONS)
list(REMOVE_DUPLICATES OPENSSL_CONFIGURE_OPTIONS)
list(PREPEND OPENSSL_CONFIGURE_OPTIONS ${OPENSSL_TARGET_PLATFORM})

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
)

# Parse configdata.pm
parse_configdata(${OPENSSL_CONFIGURE_OUTPUT} "options" FULL_CONFIGURE_OPTIONS)

if(NOT "no-shared" IN_LIST FULL_CONFIGURE_OPTIONS)
    set(OPENSSL_BUILD_SHARED_LIBS ON)
else()
    set(OPENSSL_BUILD_SHARED_LIBS OFF)
endif()

if(MSVC AND DEFINED OPENSSL_MSVC_STATIC_RT)
    if(OPENSSL_MSVC_STATIC_RT AND OPENSSL_BUILD_SHARED_LIBS)
        message(WARNING "OPENSSL_MSVC_STATIC_RT is ON, but OpenSSL will be built with /MD")
    elseif(NOT OPENSSL_MSVC_STATIC_RT AND NOT OPENSSL_BUILD_SHARED_LIBS)
        message(WARNING "OPENSSL_MSVC_STATIC_RT is OFF, but OpenSSL will be built with /MT")
    endif()
endif()

# Parse Makefile
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

if(LINUX AND NOT OPENSSL_BUILD_SHARED_LIBS)
    find_package(Threads)

    if(CMAKE_THREAD_LIBS_INIT)
        list(APPEND OPENSSL_DEPENDENCIES ${CMAKE_THREAD_LIBS_INIT})
    endif()

    list(APPEND OPENSSL_DEPENDENCIES ${CMAKE_DL_LIBS})
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

    if(MSVC)
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

    if(WIN32)
        set(OPENSSL_LINK_DEPENDENCIES ws2_32 crypt32)
    elseif(LINUX)
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
if(MSVC)
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
elseif(MINGW)
    find_program(MAKE mingw32-make REQUIRED)
    set(OPENSSL_BUILD_TOOL ${MAKE})
else()
    find_program(MAKE make REQUIRED)
    set(OPENSSL_BUILD_TOOL ${MAKE})
endif()

# Add a custom target to build OpenSSL
set(OPENSSL_BUILD_COMMAND
    ${VCVARSALL_COMMAND} ${OPENSSL_BUILD_TOOL} ${OPENSSL_BUILD_OPTIONS} ${OPENSSL_BUILD_TARGET}
)

if(ANDROID)
    list(PREPEND OPENSSL_BUILD_COMMAND
        ${CMAKE_COMMAND} -E env PATH=$ENV{PATH} --
    )
endif()

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
    VERBATIM
)

if(PROJECT_IS_TOP_LEVEL)
    add_custom_target(openssl-build ALL DEPENDS ${OPENSSL_BUILD_OUTPUT})
else()
    add_custom_target(openssl-build DEPENDS ${OPENSSL_BUILD_OUTPUT})
endif()

add_dependencies(OpenSSL::Crypto openssl-build)
add_dependencies(OpenSSL::SSL openssl-build)

# Test OpenSSL using CTest
if(OPENSSL_TEST AND NOT CMAKE_CROSSCOMPILING)
    include(CTest)
    add_test(
        NAME openssl-test
        COMMAND ${OPENSSL_BUILD_TOOL} test VERBOSE_FAILURE=yes HARNESS_JOBS=${NUMBER_OF_THREADS}
        WORKING_DIRECTORY ${openssl_BINARY_DIR}
    )
endif()

# Install OpenSSL
if(OPENSSL_INSTALL)
    set(OPENSSL_INSTALL_COMMAND ${OPENSSL_BUILD_TOOL} ${OPENSSL_INSTALL_TARGET})

    if(MSVC)
        list(APPEND OPENSSL_INSTALL_COMMAND /NOLOGO)
    endif()

    install(CODE
        "execute_process(
            COMMAND ${OPENSSL_INSTALL_COMMAND}
            WORKING_DIRECTORY ${openssl_BINARY_DIR}
            OUTPUT_QUIET
        )"
    )
endif()

if(OPENSSL_INSTALL_CERT)
    if(WIN32)
        parse_makefile(${OPENSSL_MAKEFILE} "OPENSSLDIR_dev" OPENSSL_OPENSSLDIR_DEV)
        parse_makefile(${OPENSSL_MAKEFILE} "OPENSSLDIR_dir" OPENSSL_OPENSSLDIR_DIR)
        set(OPENSSL_OPENSSLDIR ${OPENSSL_OPENSSLDIR_DEV}${OPENSSL_OPENSSLDIR_DIR})
        string(REPLACE "\\" "/" OPENSSL_OPENSSLDIR "${OPENSSL_OPENSSLDIR}")
    else()
        parse_makefile(${OPENSSL_MAKEFILE} "OPENSSLDIR" OPENSSL_OPENSSLDIR)
    endif()

    # Download latest CA certificates
    # https://curl.se/docs/caextract.html
    install(CODE "file(DOWNLOAD https://curl.se/ca/cacert.pem ${OPENSSL_OPENSSLDIR}/cert.pem)")
endif()
