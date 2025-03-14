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
            set(VCVARSALL_ARCH x86)
        elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "AMD64")
            set(VCVARSALL_ARCH x64)
        endif()

        if(NOT CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL CMAKE_SYSTEM_PROCESSOR)
            if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86")
                string(APPEND VCVARSALL_ARCH _x86)
            elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64")
                string(APPEND VCVARSALL_ARCH _x64)
            elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM")
                string(APPEND VCVARSALL_ARCH _arm)
            elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64")
                string(APPEND VCVARSALL_ARCH _arm64)
            endif()
        endif()

        if(WINDOWS_STORE)
            set(VCVARSALL_PLATFORM_TYPE uwp)
        endif()

        set(${COMMAND} ${VCVARSALL} ${VCVARSALL_ARCH} ${VCVARSALL_PLATFORM_TYPE} &&)
    endif()

    return(PROPAGATE ${COMMAND})
endfunction()
