# Find vcvarsall.bat using CMAKE_C_COMPILER
function(find_vcvarsall OUTPUT)
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
        set(${OUTPUT} ${VCVARSALL} PARENT_SCOPE)
    endif()
endfunction()