cmake_minimum_required(VERSION 3.25)

project(
    openssl-cmake
    VERSION 3.4.0
    DESCRIPTION "Build OpenSSL in parallel within CMake"
    HOMEPAGE_URL "https://github.com/jimmy-park/openssl-cmake"
    LANGUAGES C
)

if(NOT PROJECT_IS_TOP_LEVEL)
    list(APPEND CMAKE_MESSAGE_INDENT "[${PROJECT_NAME}] ")
endif()

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE NEVER)

include(FetchContent)
include(ProcessorCount)
include(cmake/ConfigureOpenSSL.cmake)
include(cmake/DetectTargetPlatform.cmake)
include(cmake/FetchOpenSSL.cmake)
include(cmake/FindVcvarsall.cmake)
include(cmake/GetCPM.cmake)

# Custom options
option(OPENSSL_BUILD_VERBOSE "Enable verbose output from build" OFF)
option(OPENSSL_CONFIGURE_VERBOSE "Enable verbose output from configuration" OFF)
option(OPENSSL_ENABLE_PARALLEL "Build and test in parallel if possible" ON)
option(OPENSSL_INSTALL "Install OpenSSL components to the <prefix> directory" OFF)
option(OPENSSL_INSTALL_CERT "Install cert.pem to the <openssldir> directory" OFF)
option(OPENSSL_TEST "Enable testing and build OpenSSL self tests" OFF)
option(OPENSSL_USE_CCACHE "Use ccache if available" ON)

if("${OPENSSL_BUILD_TARGET}" STREQUAL "")
    # Makefile target for build
    set(OPENSSL_BUILD_TARGET build_libs)
endif()

if("${OPENSSL_INSTALL_TARGET}" STREQUAL "")
    # Makefile target for install
    set(OPENSSL_INSTALL_TARGET install_dev)
endif()

if("${OPENSSL_TARGET_PLATFORM}" STREQUAL "")
    # Use OpenSSL's Configure target
    detect_target_platform(OPENSSL_TARGET_PLATFORM)
endif()

# Fetch OpenSSL source
fetch_openssl()

# Apply patches
foreach(patch IN LISTS OPENSSL_PATCH)
    if(EXISTS "${patch}" AND NOT IS_DIRECTORY "${patch}")
        if(NOT IS_ABSOLUTE "${patch}")
            string(PREPEND patch ${CMAKE_SOURCE_DIR}/)
        endif()

        execute_process(
            COMMAND git init
            WORKING_DIRECTORY ${openssl_SOURCE_DIR}
            OUTPUT_QUIET
            ERROR_QUIET
        )
        execute_process(
            COMMAND git apply ${patch}
            WORKING_DIRECTORY ${openssl_SOURCE_DIR}
            OUTPUT_QUIET
            ERROR_QUIET
        )
    endif()
endforeach()

# Run vcvarsall.bat with target architecture
set_vcvarsall_command(VCVARSALL_COMMAND)

# Set environment variables for Android NDK
if(ANDROID)
    set(ENV{PATH} ${ANDROID_TOOLCHAIN_ROOT}/bin:$ENV{PATH})
    set(ENV{ANDROID_NDK_ROOT} ${CMAKE_ANDROID_NDK})
endif()

# Set the number of threads
if(OPENSSL_ENABLE_PARALLEL)
    ProcessorCount(NUMBER_OF_THREADS)

    if(NUMBER_OF_THREADS EQUAL 0)
        set(NUMBER_OF_THREADS 1)
    endif()
else()
    set(NUMBER_OF_THREADS 1)
endif()

# Find build tool
if(MSVC)
    if(NUMBER_OF_THREADS GREATER 1)
        find_program(JOM jom)

        if(JOM)
            set(OPENSSL_BUILD_TOOL ${JOM})
        else()
            set(NUMBER_OF_THREADS 1)
        endif()
    endif()

    if(NUMBER_OF_THREADS EQUAL 1)
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

if(NUMBER_OF_THREADS GREATER 1)
    if(MSVC)
        list(APPEND OPENSSL_CONFIGURE_OPTIONS /FS)
        list(APPEND OPENSSL_BUILD_OPTIONS /J ${NUMBER_OF_THREADS})
    else()
        list(APPEND OPENSSL_BUILD_OPTIONS -j ${NUMBER_OF_THREADS})
    endif()
endif()

if(NOT BUILD_SHARED_LIBS)
    list(APPEND OPENSSL_CONFIGURE_OPTIONS no-shared)
endif()

list(SORT OPENSSL_CONFIGURE_OPTIONS)
list(REMOVE_DUPLICATES OPENSSL_CONFIGURE_OPTIONS)
list(PREPEND OPENSSL_CONFIGURE_OPTIONS ${OPENSSL_TARGET_PLATFORM})

# Configure OpenSSL
configure_openssl(
    COMMAND ${VCVARSALL_COMMAND}
    FILE ${openssl_SOURCE_DIR}/Configure
    BUILD_DIR ${openssl_BINARY_DIR}
    OPTIONS ${OPENSSL_CONFIGURE_OPTIONS}
)

# Parse configdata.pm
parse_configdata("options" OPENSSL_CONFIGURED_OPTIONS)
parse_configdata("version" OPENSSL_CONFIGURED_VERSION)

if("no-shared" IN_LIST OPENSSL_CONFIGURED_OPTIONS)
    set(OPENSSL_BUILD_SHARED_LIBS OFF)
    set(OPENSSL_LIBRARY_TYPE STATIC)
else()
    set(OPENSSL_BUILD_SHARED_LIBS ON)
    set(OPENSSL_LIBRARY_TYPE SHARED)
endif()

if(MSVC AND DEFINED OPENSSL_MSVC_STATIC_RT)
    if(OPENSSL_MSVC_STATIC_RT AND OPENSSL_BUILD_SHARED_LIBS)
        message(WARNING "OPENSSL_MSVC_STATIC_RT is ON, but OpenSSL will be built with /MD")
    elseif(NOT OPENSSL_MSVC_STATIC_RT AND NOT OPENSSL_BUILD_SHARED_LIBS)
        message(WARNING "OPENSSL_MSVC_STATIC_RT is OFF, but OpenSSL will be built with /MT")
    endif()
endif()

if(DEFINED OPENSSL_USE_STATIC_LIBS)
    if(OPENSSL_USE_STATIC_LIBS AND OPENSSL_BUILD_SHARED_LIBS)
        message(WARNING "OPENSSL_USE_STATIC_LIBS is ON, but OpenSSL will be built as a shared library")
    elseif(NOT OPENSSL_USE_STATIC_LIBS AND NOT OPENSSL_BUILD_SHARED_LIBS)
        message(WARNING "OPENSSL_USE_STATIC_LIBS is OFF, but OpenSSL will be built as a static library")
    endif()
endif()

if(BUILD_SHARED_LIBS AND NOT OPENSSL_BUILD_SHARED_LIBS)
    message(WARNING "BUILD_SHARED_LIBS is ON, but OpenSSL will be built as a static library")
elseif(NOT BUILD_SHARED_LIBS AND OPENSSL_BUILD_SHARED_LIBS)
    message(WARNING "BUILD_SHARED_LIBS is OFF, but OpenSSL will be built as a shared library")
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

if(NOT OPENSSL_BUILD_SHARED_LIBS)
    if(WIN32)
        list(APPEND OPENSSL_LINK_DEPENDENCIES ws2_32 crypt32)
    elseif(LINUX)
        find_package(Threads)

        if(Threads_FOUND)
            list(APPEND OPENSSL_LINK_DEPENDENCIES Threads::Threads)
            list(APPEND OPENSSL_DEPENDENCIES ${CMAKE_THREAD_LIBS_INIT})
        endif()

        list(APPEND OPENSSL_LINK_DEPENDENCIES ${CMAKE_DL_LIBS})
    endif()
endif()

# Provide same targets and variables as FindOpenSSL module
set(OPENSSL_FOUND ON CACHE BOOL "Override FindOpenSSL variables" FORCE)
set(OPENSSL_INCLUDE_DIR ${openssl_SOURCE_DIR}/include ${openssl_BINARY_DIR}/include CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_CRYPTO_LIBRARY ${OPENSSL_${OPENSSL_LIBRARY_TYPE}_CRYPTO_LIBRARY} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_CRYPTO_LIBRARIES ${OPENSSL_CRYPTO_LIBRARY} ${OPENSSL_DEPENDENCIES} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_SSL_LIBRARY ${OPENSSL_${OPENSSL_LIBRARY_TYPE}_SSL_LIBRARY} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_SSL_LIBRARIES ${OPENSSL_SSL_LIBRARY} ${OPENSSL_DEPENDENCIES} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_LIBRARIES ${OPENSSL_CRYPTO_LIBRARY} ${OPENSSL_SSL_LIBRARY} ${OPENSSL_DEPENDENCIES} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_VERSION ${OPENSSL_CONFIGURED_VERSION} CACHE STRING "Override FindOpenSSL variables" FORCE)
set(OPENSSL_APPLINK_SOURCE ${openssl_SOURCE_DIR}/ms/applink.c CACHE STRING "Override FindOpenSSL variables" FORCE)

add_library(OpenSSL::Crypto ${OPENSSL_LIBRARY_TYPE} IMPORTED GLOBAL)
add_library(OpenSSL::SSL ${OPENSSL_LIBRARY_TYPE} IMPORTED GLOBAL)
add_library(OpenSSL::applink INTERFACE IMPORTED GLOBAL)

set_target_properties(OpenSSL::Crypto PROPERTIES
    IMPORTED_LINK_INTERFACE_LANGUAGES C
    IMPORTED_LOCATION "${OPENSSL_CRYPTO_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "${OPENSSL_LINK_DEPENDENCIES}"
)
set_target_properties(OpenSSL::SSL PROPERTIES
    IMPORTED_LINK_INTERFACE_LANGUAGES C
    IMPORTED_LOCATION "${OPENSSL_SSL_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "${OPENSSL_LINK_DEPENDENCIES};OpenSSL::Crypto"
)

if(MSVC AND OPENSSL_BUILD_SHARED_LIBS)
    set_target_properties(OpenSSL::Crypto PROPERTIES
        IMPORTED_IMPLIB ${OPENSSL_STATIC_CRYPTO_LIBRARY}
    )
    set_target_properties(OpenSSL::SSL PROPERTIES
        IMPORTED_IMPLIB ${OPENSSL_STATIC_SSL_LIBRARY}
    )
    set_target_properties(OpenSSL::applink PROPERTIES
        INTERFACE_SOURCES ${OPENSSL_APPLINK_SOURCE}
    )

    # Overwrite cache
    set(OPENSSL_CRYPTO_LIBRARY ${OPENSSL_STATIC_CRYPTO_LIBRARY} CACHE STRING "Override FindOpenSSL variables" FORCE)
    set(OPENSSL_CRYPTO_LIBRARIES ${OPENSSL_CRYPTO_LIBRARY} ${OPENSSL_DEPENDENCIES} CACHE STRING "Override FindOpenSSL variables" FORCE)
    set(OPENSSL_SSL_LIBRARY ${OPENSSL_STATIC_SSL_LIBRARY} CACHE STRING "Override FindOpenSSL variables" FORCE)
    set(OPENSSL_SSL_LIBRARIES ${OPENSSL_SSL_LIBRARY} ${OPENSSL_DEPENDENCIES} CACHE STRING "Override FindOpenSSL variables" FORCE)
    set(OPENSSL_LIBRARIES ${OPENSSL_CRYPTO_LIBRARY} ${OPENSSL_SSL_LIBRARY} ${OPENSSL_DEPENDENCIES} CACHE STRING "Override FindOpenSSL variables" FORCE)
endif()

if(OPENSSL_CONFIGURE_VERBOSE)
    message(STATUS "OPENSSL_FOUND            : ${OPENSSL_FOUND}")
    message(STATUS "OPENSSL_INCLUDE_DIR      : ${OPENSSL_INCLUDE_DIR}")
    message(STATUS "OPENSSL_CRYPTO_LIBRARY   : ${OPENSSL_CRYPTO_LIBRARY}")
    message(STATUS "OPENSSL_CRYPTO_LIBRARIES : ${OPENSSL_CRYPTO_LIBRARIES}")
    message(STATUS "OPENSSL_SSL_LIBRARY      : ${OPENSSL_SSL_LIBRARY}")
    message(STATUS "OPENSSL_SSL_LIBRARIES    : ${OPENSSL_SSL_LIBRARIES}")
    message(STATUS "OPENSSL_LIBRARIES        : ${OPENSSL_LIBRARIES}")
    message(STATUS "OPENSSL_VERSION          : ${OPENSSL_VERSION}")
    message(STATUS "OPENSSL_APPLINK_SOURCE   : ${OPENSSL_APPLINK_SOURCE}")
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

file(GLOB_RECURSE OPENSSL_SOURCES
    ${openssl_SOURCE_DIR}/*.[ch]
    ${openssl_SOURCE_DIR}/*.[ch].in
)

set(OPENSSL_BUILD_OUTPUT
    ${OPENSSL_STATIC_CRYPTO_LIBRARY}
    ${OPENSSL_STATIC_SSL_LIBRARY}
    ${OPENSSL_SHARED_CRYPTO_LIBRARY}
    ${OPENSSL_SHARED_SSL_LIBRARY}
)
add_custom_command(
    OUTPUT ${OPENSSL_BUILD_OUTPUT}
    COMMAND ${OPENSSL_BUILD_COMMAND}
    DEPENDS ${OPENSSL_SOURCES}
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
