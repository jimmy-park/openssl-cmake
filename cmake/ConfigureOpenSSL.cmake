include(CMakeParseArguments)

function(parse_configdata FILE KEY VALUES)
    if(NOT EXISTS ${FILE})
        return()
    endif()

    if(KEY STREQUAL "perlargv")
        file(READ ${FILE} CONFIGDATA)
        string(REGEX MATCH "perlargv[^\]]*" CONFIGURE_ARGS ${CONFIGDATA})
        string(REGEX REPLACE "perlargv[^\[]*" "" CONFIGURE_ARGS ${CONFIGURE_ARGS})
        string(REGEX MATCHALL "\"[^\"]+\"" ${VALUES} ${CONFIGURE_ARGS})
        list(TRANSFORM ${VALUES} REPLACE "\"" "")
    elseif(KEY STREQUAL "options")
        file(STRINGS ${FILE} FULL_OPTIONS REGEX "options[\" ]+=>")
        string(REPLACE "\"options\"" "" FULL_OPTIONS ${FULL_OPTIONS})
        string(REGEX MATCH "\"[^\"]*\"" FULL_OPTIONS ${FULL_OPTIONS})
        string(REPLACE "\"" "" FULL_OPTIONS ${FULL_OPTIONS})
        string(REPLACE " " ";" ${VALUES} ${FULL_OPTIONS})
    endif()

    return(PROPAGATE ${VALUES})
endfunction()

function(lookup_makefile STRING KEY VALUES)
    string(REGEX MATCH "\n${KEY}=[^\n]*" OUTPUT "${STRING}")
    string(REGEX REPLACE "\n${KEY}=[ ]*" "" ${VALUES} "${OUTPUT}")

    return(PROPAGATE ${VALUES})
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
    string(REGEX REPLACE "[ ]+" ";" ${VALUES} "${OUTPUT}")
    list(REMOVE_ITEM ${VALUES} "")

    return(PROPAGATE ${VALUES})
endfunction()

function(apply_ccache FILE)
    if(NOT EXISTS ${FILE})
        message(FATAL_ERROR "Couldn't find Makefile")
    endif()

    if(OPENSSL_USE_CCACHE)
        find_program(CCACHE ccache)

        if(NOT CCACHE)
            return()
        endif()

        file(READ ${FILE} MAKEFILE)

        if(MSVC)
            string(REGEX REPLACE "\nCC=[^\n]*" "CC=ccache cl" MAKEFILE "${MAKEFILE}")
            string(REPLACE "/Zi /Fdossl_static.pdb " "" MAKEFILE "${MAKEFILE}")
            string(REPLACE "/Zi /Fddso.pdb " "" MAKEFILE "${MAKEFILE}")
            string(REPLACE "/Zi /Fdapp.pdb " "" MAKEFILE "${MAKEFILE}")
        else()
            parse_makefile(${FILE} "CC" OPENSSL_C_COMPILER)
            string(REPLACE ";" " " OPENSSL_C_COMPILER "${OPENSSL_C_COMPILER}")
            string(REGEX REPLACE "\nCC=[^\n]*" "\nCC=${CCACHE} ${OPENSSL_C_COMPILER}" MAKEFILE "${MAKEFILE}")
        endif()

        file(WRITE ${FILE} "${MAKEFILE}")
    endif()
endfunction()

function(configure_openssl)
    cmake_parse_arguments(
        CONFIGURE
        "" # options
        "TOOL;FILE;BUILD_DIR;OUTPUT" # one_value_keywords
        "COMMAND;OPTIONS" # multi_value_keywords
        ${ARGN}
    )

    message(STATUS "Curruent configure options : ${CONFIGURE_OPTIONS}")

    # Find previous configure results
    parse_configdata(${CONFIGURE_OUTPUT} "perlargv" CONFIGURE_OPTIONS_OLD)

    if(NOT "${CONFIGURE_OPTIONS_OLD}" STREQUAL "")
        if(CONFIGURE_OPTIONS STREQUAL CONFIGURE_OPTIONS_OLD)
            message(STATUS "Found previous configure results. Don't perform configuration")
            return()
        endif()

        if(IS_DIRECTORY ${CONFIGURE_BUILD_DIR})
            message(STATUS "Previous configure options : ${CONFIGURE_OPTIONS_OLD}")
            message(STATUS "Configure options are changed. Clean build directory")
            file(REMOVE_RECURSE ${CONFIGURE_BUILD_DIR})
        endif()
    endif()

    if(NOT IS_DIRECTORY ${CONFIGURE_BUILD_DIR})
        file(MAKE_DIRECTORY ${CONFIGURE_BUILD_DIR})
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

    if(OPENSSL_CONFIGURE_VERBOSE)
        set(VERBOSE_OPTION "")
    else()
        set(VERBOSE_OPTION OUTPUT_QUIET)
    endif()

    execute_process(
        COMMAND ${CONFIGURE_COMMAND}
        WORKING_DIRECTORY ${CONFIGURE_BUILD_DIR}
        ${VERBOSE_OPTION}
        COMMAND_ERROR_IS_FATAL ANY
    )

    if(OPENSSL_CONFIGURE_VERBOSE)
        execute_process(
            COMMAND ${CONFIGURE_TOOL} ${CONFIGURE_OUTPUT} -d
            WORKING_DIRECTORY ${CONFIGURE_BUILD_DIR}
            COMMAND_ERROR_IS_FATAL ANY
        )
    endif()

    # Modify Makefile
    find_file(
        OPENSSL_MAKEFILE
        NAMES makefile Makefile
        PATHS ${CONFIGURE_BUILD_DIR}
        REQUIRED
        NO_DEFAULT_PATH
    )
    apply_ccache(${OPENSSL_MAKEFILE})

    if(WIN32 AND NOT OPENSSL_BUILD_VERBOSE)
        file(READ ${OPENSSL_MAKEFILE} MAKEFILE)
        string(REPLACE "/W3" "/W0" MAKEFILE "${MAKEFILE}")
        file(WRITE ${OPENSSL_MAKEFILE} "${MAKEFILE}")
    endif()
endfunction()