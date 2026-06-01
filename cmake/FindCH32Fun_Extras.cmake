# FindCH32Fun_Extras.cmake
#
# Locates the extralibs/ directory from within the same ch32fun repository
# checkout used by FindCH32Fun_Framework.  Depends on CH32FUN_FRAMEWORK_FOUND.
#
# Variables that can be set:
#   CH32FUN_EXTRAS_PATH  - Path to the extralibs directory (optional).
#                           If not set, resolved from the framework checkout.
#
# Variables defined by this module:
#   CH32FUN_EXTRAS_FOUND         - True if the extras module was located.
#   CH32FUN_EXTRAS_INCLUDE_DIR   - extralibs include directory.
#

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# 1. If the user already provided a path, use it.
# ---------------------------------------------------------------------------
if(CH32FUN_EXTRAS_PATH)
    if(NOT IS_DIRECTORY "${CH32FUN_EXTRAS_PATH}")
        message(FATAL_ERROR
            "CH32FUN_EXTRAS_PATH is set to '${CH32FUN_EXTRAS_PATH}' "
            "but that directory does not exist.")
    endif()

    set(CH32FUN_EXTRAS_FOUND       TRUE)
    set(CH32FUN_EXTRAS_INCLUDE_DIR "${CH32FUN_EXTRAS_PATH}")

    message(STATUS "CH32Fun_Extras: using path '${CH32FUN_EXTRAS_PATH}'")
    return()
endif()

# ---------------------------------------------------------------------------
# 2. Resolve from the framework checkout (same repo, extralibs/ is a sibling
#    of ch32fun/ at the repo root).
# ---------------------------------------------------------------------------
if(NOT CH32FUN_FRAMEWORK_FOUND)
    find_package(CH32Fun_Framework REQUIRED)
endif()

get_filename_component(_repo_root "${CH32FUN_FRAMEWORK_SOURCE_DIR}" DIRECTORY)
set(_extras_dir "${_repo_root}/extralibs")

if(NOT IS_DIRECTORY "${_extras_dir}")
    message(FATAL_ERROR
        "CH32Fun_Extras: extralibs not found at '${_extras_dir}'.\n"
        "  The ch32fun repository may have an unexpected structure.")
endif()

set(CH32FUN_EXTRAS_FOUND       TRUE)
set(CH32FUN_EXTRAS_INCLUDE_DIR "${_extras_dir}")

message(STATUS "CH32Fun_Extras: found at '${_extras_dir}'")
