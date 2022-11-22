include(CMakeParseArguments)

function(detect_target_platform RESULT)
    if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
        if(CMAKE_GENERATOR_PLATFORM STREQUAL "")
            set(CMAKE_GENERATOR_PLATFORM ${CMAKE_VS_PLATFORM_NAME_DEFAULT})
        endif()

        if(CMAKE_GENERATOR_PLATFORM STREQUAL "Win32")
            set(TARGET_PLATFORM VC-WIN32)
        elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "x64")
            set(TARGET_PLATFORM VC-WIN64A)
        elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM")
            set(TARGET_PLATFORM VC-WIN32-ARM)
        elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
            set(TARGET_PLATFORM VC-WIN64-ARM)
        endif()
    endif()

    if(NOT DEFINED TARGET_PLATFORM)
        message(FATAL_ERROR "Failed to detect the OpenSSL target platform")
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
        string(FIND ${CONFIGURE_ARGS} "[" BEGIN_POS)
        math(EXPR BEGIN_POS "${BEGIN_POS} + 1")
        string(SUBSTRING ${CONFIGURE_ARGS} ${BEGIN_POS} -1 CONFIGURE_ARGS)
        string(REGEX REPLACE "[\"\n ]" "" CONFIGURE_ARGS ${CONFIGURE_ARGS})
        string(REPLACE "," ";" CONFIGURE_ARGS ${CONFIGURE_ARGS})
        set(${VALUES} ${CONFIGURE_ARGS} PARENT_SCOPE)
    elseif(KEY STREQUAL "options")
        file(STRINGS ${FILE} FULL_OPTIONS REGEX "options.*\".*\"")
        string(FIND ${FULL_OPTIONS} ">" BEGIN_POS)
        math(EXPR BEGIN_POS "${BEGIN_POS} + 2")
        string(SUBSTRING ${FULL_OPTIONS} ${BEGIN_POS} -1 FULL_OPTIONS)
        string(REGEX REPLACE "[\",]" "" FULL_OPTIONS ${FULL_OPTIONS})
        string(REPLACE " " ";" FULL_OPTIONS ${FULL_OPTIONS})
        set(${VALUES} ${FULL_OPTIONS} PARENT_SCOPE)
    endif()
endfunction()

function(parse_makefile FILE KEY VALUES)
    if(NOT EXISTS ${FILE})
        return()
    endif()

    if(KEY STREQUAL "static")
        file(STRINGS ${FILE} LIBRARIES REGEX "INSTALL_LIBS=")
    elseif(KEY STREQUAL "shared")
        file(STRINGS ${FILE} LIBRARIES REGEX "INSTALL_SHLIBS=")
    else()
        return()
    endif()

    string(FIND ${LIBRARIES} "=" BEGIN_POS)
    math(EXPR BEGIN_POS "${BEGIN_POS} + 1")
    string(SUBSTRING ${LIBRARIES} ${BEGIN_POS} -1 LIBRARIES)
    string(REGEX REPLACE "[\"]" "" LIBRARIES "${LIBRARIES}")
    string(REPLACE " " ";" LIBRARIES "${LIBRARIES}")
    set(${VALUES} ${LIBRARIES} PARENT_SCOPE)
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

    # Set environment variables before configuration
    set(ENV{PERL} ${CONFIGURE_TOOL})

    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        set(ENV{RANLIB} "ranlib -c -no_warning_for_no_symbols")
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