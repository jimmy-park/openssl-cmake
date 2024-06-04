function(fetch_openssl)
    if("${OPENSSL_SOURCE}" MATCHES "^http")
        # Download OpenSSL source from the internet
        CPMAddPackage(
            NAME openssl-source
            URL ${OPENSSL_SOURCE}
            DOWNLOAD_ONLY ON
        )
    elseif(EXISTS "${OPENSSL_SOURCE}" AND IS_DIRECTORY "${OPENSSL_SOURCE}")
        # Fetch the local OpenSSL source
        if(NOT IS_ABSOLUTE "${OPENSSL_SOURCE}")
            string(PREPEND OPENSSL_SOURCE ${CMAKE_SOURCE_DIR}/)
        endif()

        string(REPLACE "\\" "/" openssl-source_SOURCE_DIR "${OPENSSL_SOURCE}")
        set(openssl-source_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/openssl-source-build)
    else()
        # Download OpenSSL source from the official website
        if("${OPENSSL_TARGET_VERSION}" STREQUAL "")
            set(OPENSSL_TARGET_VERSION ${PROJECT_VERSION})
        endif()

        if(OPENSSL_TARGET_VERSION VERSION_EQUAL PROJECT_VERSION)
            set(CPM_HASH_OPTION URL_HASH SHA256=777cd596284c883375a2a7a11bf5d2786fc5413255efab20c50d6ffe6d020b7e)
        else()
            set(CPM_HASH_OPTION "")
        endif()

        CPMAddPackage(
            NAME openssl-source
            URL https://www.openssl.org/source/openssl-${OPENSSL_TARGET_VERSION}.tar.gz
            DOWNLOAD_ONLY ON
            ${CPM_HASH_OPTION}
        )
    endif()

    # Clean build directory if source directory has changed
    if(NOT openssl-source_SOURCE_DIR STREQUAL openssl-source_SOURCE_DIR_OLD)
        set(openssl-source_SOURCE_DIR_OLD ${openssl-source_SOURCE_DIR} CACHE INTERNAL "Previously fetched OpenSSL source")

        if(IS_DIRECTORY ${openssl-source_BINARY_DIR})
            file(REMOVE_RECURSE ${openssl-source_BINARY_DIR})
            file(MAKE_DIRECTORY ${openssl-source_BINARY_DIR})
        endif()
    endif()

    # Override the FindOpenSSL module
    FetchContent_Declare(
        OpenSSL
        SOURCE_DIR ${openssl-source_SOURCE_DIR}
        BINARY_DIR ${openssl-source_BINARY_DIR}
        OVERRIDE_FIND_PACKAGE
    )
    FetchContent_MakeAvailable(OpenSSL)

    return(PROPAGATE openssl_SOURCE_DIR openssl_BINARY_DIR)
endfunction()
