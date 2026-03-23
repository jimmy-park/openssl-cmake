list(APPEND CMAKE_MESSAGE_INDENT "[CheckSourceHash] ")

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

list(SORT SOURCES)

list(LENGTH SOURCES SOURCE_COUNT)
message(STATUS "SOURCE_DIR  : ${SOURCE_DIR}")
message(STATUS "HASH_FILE   : ${HASH_FILE}")
message(STATUS "Source count : ${SOURCE_COUNT}")

set(HASH_INPUT "")

foreach(source IN LISTS SOURCES)
    file(MD5 "${source}" FILE_HASH)
    string(APPEND HASH_INPUT "${FILE_HASH}")
endforeach()

string(MD5 COMPUTED_HASH "${HASH_INPUT}")

if(EXISTS "${HASH_FILE}")
    file(READ "${HASH_FILE}" OLD_HASH)
    message(STATUS "Old hash    : ${OLD_HASH}")
else()
    message(STATUS "Old hash    : (not found)")
endif()

message(STATUS "New hash    : ${COMPUTED_HASH}")

if(NOT COMPUTED_HASH STREQUAL OLD_HASH)
    message(STATUS "Hash changed, updating hash file")
    file(WRITE "${HASH_FILE}" "${COMPUTED_HASH}")
else()
    message(STATUS "Hash unchanged, skipping update")
endif()
