function(detect_target_platform TARGET)
    set(${TARGET} "")

    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(PREFIX 64)
    endif()

    if(MSVC)
        if(CMAKE_GENERATOR_PLATFORM STREQUAL "")
            set(CMAKE_GENERATOR_PLATFORM ${CMAKE_VS_PLATFORM_NAME_DEFAULT})
        endif()

        if(CMAKE_GENERATOR_PLATFORM STREQUAL "Win32")
            set(${TARGET} VC-WIN32)
        elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "x64")
            set(${TARGET} VC-WIN64A)
        elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM")
            set(${TARGET} VC-WIN32-ARM)
        elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
            set(${TARGET} VC-WIN64-ARM)
        endif()
    elseif(MINGW)
        set(${TARGET} mingw${PREFIX})
    elseif(CYGWIN)
        set(${TARGET} Cygwin-${CMAKE_SYSTEM_PROCESSOR})
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        set(${TARGET} darwin${PREFIX}-${CMAKE_SYSTEM_PROCESSOR}-cc)
    elseif(IOS)
        if(CMAKE_OSX_SYSROOT STREQUAL "iphoneos")
            set(${TARGET} ios64-xcrun)
        elseif(CMAKE_OSX_SYSROOT STREQUAL "iphonesimulator")
            set(${TARGET} iossimulator-xcrun)
        endif()
    elseif(ANDROID)
        if(CMAKE_ANDROID_ARCH_ABI STREQUAL "armeabi-v7a")
            set(${TARGET} android-arm)
        elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
            set(${TARGET} android-arm64)
        elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86")
            set(${TARGET} android-x86)
        elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64")
            set(${TARGET} android-x86_64)
        endif()
    elseif(LINUX)
        set(${TARGET} linux-${CMAKE_SYSTEM_PROCESSOR})

        if(CMAKE_C_COMPILER_ID MATCHES "Clang")
            string(APPEND ${TARGET} -clang)
        endif()
    elseif(BSD)
        string(TOLOWER ${CMAKE_SYSTEM_PROCESSOR} PROCESSOR)

        if(PROCESSOR STREQUAL "i386")
            set(${TARGET} BSD-x86)
        elseif(PROCESSOR STREQUAL "amd64")
            set(${TARGET} BSD-x86_64)
        else()
            set(${TARGET} BSD-${CMAKE_SYSTEM_PROCESSOR})
        endif()
    elseif(CMAKE_SYSTEM_NAME STREQUAL "SunOS")
        set(${TARGET} solaris${PREFIX}-${CMAKE_SYSTEM_PROCESSOR}-gcc)
    endif()

    if(${TARGET} STREQUAL "")
        message(WARNING "Failed to detect the target platform for OpenSSL")
    endif()

    return(PROPAGATE ${TARGET})
endfunction()
