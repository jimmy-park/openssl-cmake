project(apps LANGUAGES CXX)
add_executable(main main.cpp)
target_link_libraries(main PRIVATE
    OpenSSL::SSL
    OpenSSL::Crypto
    $<$<CXX_COMPILER_ID:MSVC>:OpenSSL::applink>
)

if(OPENSSL_BUILD_SHARED_LIBS AND CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    add_custom_command(
        TARGET main
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_RUNTIME_DLLS:main> $<TARGET_FILE_DIR:main>
        COMMENT "Copy OpenSSL .dll files to binary directory"
        COMMAND_EXPAND_LISTS
    )
endif()