function(clean_directory PATH)
    if(IS_DIRECTORY ${PATH})
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E rm -rf ${PATH}
            COMMAND_ERROR_IS_FATAL ANY
        )
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E make_directory ${PATH}
            COMMAND_ERROR_IS_FATAL ANY
        )
    else()
        message(FATAL_ERROR "${PATH} isn't directory")
    endif()
endfunction()