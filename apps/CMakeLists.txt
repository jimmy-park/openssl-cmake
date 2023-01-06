if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL CMAKE_SYSTEM_NAME)
    return()
endif()

project(apps LANGUAGES CXX)

add_executable(main main.cpp)
target_link_libraries(main PRIVATE
    OpenSSL::SSL
    OpenSSL::Crypto
    $<$<CXX_COMPILER_ID:MSVC>:OpenSSL::applink>
)

if(OPENSSL_BUILD_SHARED_LIBS AND CMAKE_GENERATOR MATCHES "Visual Studio")
    set_target_properties(main PROPERTIES
        VS_DEBUGGER_ENVIRONMENT "PATH=%PATH%;${openssl_BINARY_DIR}"
    )
endif()