include(CMakeParseArguments)

function(detect_target_platform RESULT)
    if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
        if(CMAKE_GENERATOR_PLATFORM STREQUAL "")
            set(CMAKE_GENERATOR_PLATFORM ${CMAKE_VS_PLATFORM_NAME_DEFAULT})
        endif()

        if(CMAKE_GENERATOR_PLATFORM STREQUAL "Win32")
            set(TARGET_PLATFORM "VC-WIN32")
        elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "x64")
            set(TARGET_PLATFORM "VC-WIN64A")
        elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM")
            set(TARGET_PLATFORM "VC-WIN32-ARM")
        elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
            set(TARGET_PLATFORM "VC-WIN64-ARM")
        endif()
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
            set(TARGET_PLATFORM "darwin64-x86_64-cc")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64")
            set(TARGET_PLATFORM "darwin64-arm64-cc")
        endif()
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
            set(TARGET_PLATFORM "linux-x86_64")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
            set(TARGET_PLATFORM "linux-aarch64")
        endif()
    endif()

    if(NOT DEFINED TARGET_PLATFORM)
        message(FATAL_ERROR "Failed to detect OpenSSL target platform")
    endif()

    set(${RESULT} ${TARGET_PLATFORM} PARENT_SCOPE)
endfunction()

function(parse_configdata FILE KEY VALUES)
    if(NOT EXISTS ${FILE})
        return()
    endif()

    if(KEY STREQUAL "perlargv")
        file(READ ${FILE} CONFIGDATA)
        string(REGEX MATCH "perlargv[^\]]*" CONFIGURE_ARGS ${CONFIGDATA})
        string(REGEX REPLACE "perlargv[^\[]*" "" CONFIGURE_ARGS ${CONFIGURE_ARGS})
        string(REGEX MATCHALL "\"[^\"]+\"" CONFIGURE_ARGS ${CONFIGURE_ARGS})
        list(TRANSFORM CONFIGURE_ARGS REPLACE "\"" "")
        set(${VALUES} ${CONFIGURE_ARGS} PARENT_SCOPE)
    elseif(KEY STREQUAL "options")
        file(STRINGS ${FILE} FULL_OPTIONS REGEX "options[\" ]+=>")
        string(REPLACE "\"options\"" "" FULL_OPTIONS ${FULL_OPTIONS})
        string(REGEX MATCH "\"[^\"]*\"" FULL_OPTIONS ${FULL_OPTIONS})
        string(REPLACE "\"" "" FULL_OPTIONS ${FULL_OPTIONS})
        string(REPLACE " " ";" FULL_OPTIONS ${FULL_OPTIONS})
        set(${VALUES} ${FULL_OPTIONS} PARENT_SCOPE)
    endif()
endfunction()

function(lookup_makefile STRING KEY VALUES)
    string(REGEX MATCH "${KEY}=[^\n]*" OUTPUT "${STRING}")
    string(REGEX REPLACE "${KEY}=[ ]*" "" OUTPUT "${OUTPUT}")
    set(${VALUES} ${OUTPUT} PARENT_SCOPE)
endfunction()

function(parse_makefile FILE KEY VALUES)
    if(NOT EXISTS ${FILE})
        message(FATAL_ERROR "Couldn't find Makefile")
    endif()

    file(READ ${FILE} MAKEFILE)
    string(REGEX REPLACE "[\\]\n" "" MAKEFILE "${MAKEFILE}")
    lookup_makefile("${MAKEFILE}" ${KEY} OUTPUT)

    # Variable expansion
    while(TRUE)
        string(REGEX MATCH "[\$][^\)]*[\)]" VARIABLE "${OUTPUT}")

        if("${VARIABLE}" STREQUAL "")
            break()
        endif()

        string(REGEX REPLACE "[\$\(\)]" "" SUBKEY "${VARIABLE}")
        lookup_makefile("${MAKEFILE}" ${SUBKEY} SUBVALUE)
        string(REPLACE "${VARIABLE}" "${SUBVALUE}" OUTPUT "${OUTPUT}")
    endwhile()

    string(REPLACE "\"" "" OUTPUT "${OUTPUT}")
    string(REGEX REPLACE "[ ]+" ";" OUTPUT "${OUTPUT}")
    list(REMOVE_ITEM OUTPUT "")
    set(${VALUES} ${OUTPUT} PARENT_SCOPE)
endfunction()

function(configure_openssl)
    cmake_parse_arguments(
        CONFIGURE
        "" # options
        "TOOL;FILE;BUILD_DIR;OUTPUT;VERBOSE" # one_value_keywords
        "COMMAND;OPTIONS" # multi_value_keywords
        ${ARGN}
    )

    message(STATUS "Curruent configure options : ${CONFIGURE_OPTIONS}")

    # Find previous configure results
    parse_configdata(${CONFIGURE_OUTPUT} "perlargv" CONFIGURE_OPTIONS_OLD)

    if(NOT "${CONFIGURE_OPTIONS_OLD}" STREQUAL "")
        message(STATUS "Previous configure options : ${CONFIGURE_OPTIONS_OLD}")

        if(CONFIGURE_OPTIONS STREQUAL CONFIGURE_OPTIONS_OLD)
            message(STATUS "Found previous configure results. Don't perform configuration")
            return()
        endif()

        if(IS_DIRECTORY ${CONFIGURE_BUILD_DIR})
            message(STATUS "Configure options are changed. Clean build directory")
            file(REMOVE_RECURSE ${CONFIGURE_BUILD_DIR})
            file(MAKE_DIRECTORY ${CONFIGURE_BUILD_DIR})
        endif()
    endif()

    execute_process(
        COMMAND ${CONFIGURE_TOOL} ${CONFIGURE_FILE} LIST
        WORKING_DIRECTORY ${CONFIGURE_BUILD_DIR}
        OUTPUT_VARIABLE PLATFORM_LIST
        COMMAND_ERROR_IS_FATAL ANY
    )
    string(REPLACE "\n" ";" PLATFORM_LIST ${PLATFORM_LIST})
    list(GET CONFIGURE_OPTIONS 0 TARGET_PLATFORM)

    if(NOT TARGET_PLATFORM IN_LIST PLATFORM_LIST)
        message(FATAL_ERROR "${TARGET_PLATFORM} isn't supported")
    endif()

    message(STATUS "Configure OpenSSL")
    list(APPEND CONFIGURE_COMMAND ${CONFIGURE_TOOL} ${CONFIGURE_FILE} ${CONFIGURE_OPTIONS})

    if(CONFIGURE_VERBOSE)
        execute_process(
            COMMAND ${CONFIGURE_COMMAND}
            WORKING_DIRECTORY ${CONFIGURE_BUILD_DIR}
            COMMAND_ERROR_IS_FATAL ANY
        )
    else()
        execute_process(
            COMMAND ${CONFIGURE_COMMAND}
            WORKING_DIRECTORY ${CONFIGURE_BUILD_DIR}
            OUTPUT_QUIET
            COMMAND_ERROR_IS_FATAL ANY
        )
    endif()
endfunction()