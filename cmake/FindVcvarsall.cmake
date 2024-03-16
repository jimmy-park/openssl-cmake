# Find vcvarsall.bat using CMAKE_C_COMPILER
function(find_vcvarsall)
    if(NOT "${VCVARSALL}" STREQUAL "")
        return()
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
endfunction()

function(set_vcvarsall_command COMMAND)
    set(${COMMAND} "")

    if(MSVC)
        find_vcvarsall()

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

        if(NOT "${VCVARSALL_ARCH}" STREQUAL "")
            set(${COMMAND} ${VCVARSALL} ${VCVARSALL_ARCH} &&)
        endif()
    endif()

    return(PROPAGATE ${COMMAND})
endfunction()
