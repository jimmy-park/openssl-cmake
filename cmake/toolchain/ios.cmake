set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_DEPLOYMENT_TARGET 7.0)
list(APPEND OPENSSL_CONFIGURE_OPTIONS
    no-shared
    no-tests
    -fembed-bitcode
    -fvisibility=hidden
    -fvisibility-inlines-hidden
    -fPIC
)

if(CMAKE_OSX_SYSROOT STREQUAL "iphoneos")
    set(CMAKE_SYSTEM_PROCESSOR aarch64)
    set(CMAKE_OSX_ARCHITECTURES arm64)
    set(OPENSSL_TARGET_PLATFORM ios64-xcrun)
elseif(CMAKE_OSX_SYSROOT STREQUAL "iphonesimulator")
    set(CMAKE_OSX_ARCHITECTURES arm64 x86_64)
    set(CMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH NO)
    set(OPENSSL_TARGET_PLATFORM iossimulator-xcrun)
    list(APPEND OPENSSL_CONFIGURE_OPTIONS
        no-asm
        "-arch arm64"
        "-arch x86_64"
        -mios-simulator-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET}
        -fno-common
        -DL_ENDIAN
    )
else()
    message(FATAL_ERROR "CMAKE_OSX_SYSROOT isn't specified")
endif()

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)