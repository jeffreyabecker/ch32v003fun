# FindCH32Fun.cmake
#
# This module locates the CH32Fun framework for WCH RISC-V MCUs.
#
# Variables that can be set:
#   CH32FUN_FRAMEWORK_PATH  - Path to the ch32fun framework (optional).
#                              If not set, the framework will be fetched from
#                              GitHub via FetchContent.
#
# Variables defined by this module:
#   CH32FUN_FRAMEWORK_FOUND           - True if the framework was found/fetched.
#   CH32FUN_FRAMEWORK_INCLUDE_DIR     - Include directory for ch32fun headers.
#   CH32FUN_FRAMEWORK_SOURCE_DIR      - Directory containing ch32fun source files.
#

# ---------------------------------------------------------------------------
# 1. If the user already provided a path, use it.
# ---------------------------------------------------------------------------
if(CH32FUN_FRAMEWORK_PATH)
    if(NOT IS_DIRECTORY "${CH32FUN_FRAMEWORK_PATH}")
        message(FATAL_ERROR
            "CH32FUN_FRAMEWORK_PATH is set to '${CH32FUN_FRAMEWORK_PATH}' "
            "but that directory does not exist.")
    endif()

    set(CH32FUN_FRAMEWORK_FOUND TRUE)
    set(CH32FUN_FRAMEWORK_SOURCE_DIR "${CH32FUN_FRAMEWORK_PATH}")
    set(CH32FUN_FRAMEWORK_INCLUDE_DIR "${CH32FUN_FRAMEWORK_PATH}")

    message(STATUS "CH32Fun: using framework at '${CH32FUN_FRAMEWORK_PATH}'")
    return()
endif()

# ---------------------------------------------------------------------------
# 2. Otherwise, use FetchContent to clone from GitHub.
# ---------------------------------------------------------------------------
message(STATUS "CH32Fun: CH32FUN_FRAMEWORK_PATH not set – fetching from GitHub")

include(FetchContent)

FetchContent_Declare(
    ch32fun
    GIT_REPOSITORY  https://github.com/cnlohr/ch32fun.git
    GIT_TAG         master
    GIT_SHALLOW     TRUE
)

# FetchContent_MakeAvailable will populate the source tree.  Since
# SOURCE_SUBDIR ch32fun selects the ch32fun sub-tree (which has no
# CMakeLists.txt), no add_subdirectory is triggered.
FetchContent_MakeAvailable(ch32fun)

set(CH32FUN_FRAMEWORK_FOUND       TRUE)
set(CH32FUN_FRAMEWORK_SOURCE_DIR  "${ch32fun_SOURCE_DIR}/ch32fun")
set(CH32FUN_FRAMEWORK_INCLUDE_DIR "${ch32fun_SOURCE_DIR}/ch32fun")

message(STATUS "CH32Fun: fetched framework to '${ch32fun_SOURCE_DIR}/ch32fun'")
