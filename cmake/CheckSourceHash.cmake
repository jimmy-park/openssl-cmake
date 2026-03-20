if(NOT IS_DIRECTORY "${SOURCE_DIR}")
    message(FATAL_ERROR "SOURCE_DIR is not a valid directory: ${SOURCE_DIR}")
endif()

file(GLOB_RECURSE SOURCES
    ${SOURCE_DIR}/*.[ch]
    ${SOURCE_DIR}/*.[ch].in
)

if(NOT SOURCES)
    message(FATAL_ERROR "No source files found in: ${SOURCE_DIR}")
endif()

set(HASH_INPUT "")

foreach(source IN LISTS SOURCES)
    file(MD5 "${source}" FILE_HASH)
    string(APPEND HASH_INPUT "${FILE_HASH}")
endforeach()

string(MD5 COMPUTED_HASH "${HASH_INPUT}")

if(EXISTS "${HASH_FILE}")
    file(READ "${HASH_FILE}" OLD_HASH)
endif()

if(NOT COMPUTED_HASH STREQUAL OLD_HASH)
    file(WRITE "${HASH_FILE}" "${COMPUTED_HASH}")
endif()
