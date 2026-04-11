function(check_build_mismatches)
    if(OPENSSL_BUILD_SHARED_LIBS)
        if(MSVC AND DEFINED OPENSSL_MSVC_STATIC_RT AND OPENSSL_MSVC_STATIC_RT)
            message(WARNING
                "OPENSSL_MSVC_STATIC_RT=ON, but OpenSSL resolved to a ${OPENSSL_LIBRARY_TYPE} build and will use /MD.\n"
                "Disable shared libraries to keep the static MSVC runtime."
            )
        endif()

        if(DEFINED OPENSSL_USE_STATIC_LIBS AND OPENSSL_USE_STATIC_LIBS)
            message(WARNING
                "OPENSSL_USE_STATIC_LIBS=ON, but OpenSSL resolved to a ${OPENSSL_LIBRARY_TYPE} build.\n"
                "Check BUILD_SHARED_LIBS and OPENSSL_CONFIGURE_OPTIONS."
            )
        endif()

        if(NOT BUILD_SHARED_LIBS)
            message(WARNING
                "BUILD_SHARED_LIBS=OFF, but OpenSSL resolved to a ${OPENSSL_LIBRARY_TYPE} build.\n"
                "Check OPENSSL_CONFIGURE_OPTIONS for options that override the default no-shared behavior."
            )
        endif()
    else()
        if(MSVC AND DEFINED OPENSSL_MSVC_STATIC_RT AND NOT OPENSSL_MSVC_STATIC_RT)
            message(WARNING
                "OPENSSL_MSVC_STATIC_RT=OFF, but OpenSSL resolved to a ${OPENSSL_LIBRARY_TYPE} build and will use /MT.\n"
                "Enable shared libraries to keep the dynamic MSVC runtime."
            )
        endif()

        if(DEFINED OPENSSL_USE_STATIC_LIBS AND NOT OPENSSL_USE_STATIC_LIBS)
            message(WARNING
                "OPENSSL_USE_STATIC_LIBS=OFF, but OpenSSL resolved to a ${OPENSSL_LIBRARY_TYPE} build.\n"
                "Check BUILD_SHARED_LIBS and OPENSSL_CONFIGURE_OPTIONS."
            )
        endif()

        if(BUILD_SHARED_LIBS)
            message(WARNING
                "BUILD_SHARED_LIBS=ON, but OpenSSL resolved to a ${OPENSSL_LIBRARY_TYPE} build.\n"
                "Check OPENSSL_CONFIGURE_OPTIONS for options such as no-shared that override the default build type."
            )
        endif()
    endif()
endfunction()
