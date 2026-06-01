# ============================================================================
# ch32fun.cmake  —  Bootstrap / umbrella module
#
# Single entry point for the entire ch32fun CMake toolchain.  Place this
# file alone in your project's cmake/ directory.  On first run it fetches
# the remaining cmake modules from GitHub, then chains through them:
#
#   cmake_minimum_required(VERSION 3.18)
#   include(cmake/ch32fun.cmake)
#   project(myapp C ASM)
#   add_executable(myapp main.c)
#   ch32fun_configure(TARGET myapp MCU CH32V003)
#
# This file does the following:
#   1. Downloads the missing cmake modules from the repo (one-time).
#   2. Downloads and configures the xPack RISC-V GCC toolchain.
#   3. Locates (or fetches) the CH32Fun framework from GitHub.
#   4. Locates the extralibs/ helper module within the framework.
#   5. Loads the ch32fun_configure() function for MCU target setup.
#
# Cache variables (set before include to override defaults):
#   CH32FUN_FRAMEWORK_REPO  — Base URL for the ch32fun repository.
#                               Default: https://github.com/cnlohr/ch32fun
#   CH32FUN_FRAMEWORK_REF   — Git ref (tag or branch) for the framework.
#                               Default: master
# ============================================================================

include_guard(GLOBAL)

# ── 0. Bootstrap: fetch missing cmake modules ───────────────────────────────

if(NOT CH32FUN_FRAMEWORK_REPO)
    set(CH32FUN_FRAMEWORK_REPO
        "https://github.com/cnlohr/ch32fun"
        CACHE STRING "Base URL for the ch32fun repository")
endif()

if(NOT CH32FUN_FRAMEWORK_REF)
    set(CH32FUN_FRAMEWORK_REF "master" CACHE STRING
        "Git ref (tag or branch) for the ch32fun framework")
endif()

# Directory to cache the downloaded modules alongside this file.
set(_cmake_cache "${CMAKE_CURRENT_LIST_DIR}")

foreach(_mod ch32fun-toolchain FindCH32Fun_Framework FindCH32Fun_Extras ch32fun-configure)
    set(_dst "${_cmake_cache}/${_mod}.cmake")
    if(NOT EXISTS "${_dst}")
        message(STATUS "ch32fun: fetching ${_mod}.cmake …")
        file(DOWNLOAD "${CH32FUN_FRAMEWORK_REPO}/${CH32FUN_FRAMEWORK_REF}/cmake/${_mod}.cmake" "${_dst}"
             STATUS _dl TIMEOUT 60)
        list(GET _dl 0 _code)
        if(NOT _code EQUAL 0)
            list(GET _dl 1 _msg)
            file(REMOVE "${_dst}")
            message(FATAL_ERROR "ch32fun: failed to fetch ${_mod}.cmake: ${_msg}")
        endif()
    endif()
endforeach()

# ── 1. Toolchain ────────────────────────────────────────────────────────────

include("${_cmake_cache}/ch32fun-toolchain.cmake")

# ── 2. Framework (locate or FetchContent) ───────────────────────────────────

list(APPEND CMAKE_MODULE_PATH "${_cmake_cache}")
find_package(CH32Fun_Framework REQUIRED)

# ── 3. Extras ───────────────────────────────────────────────────────────────

find_package(CH32Fun_Extras REQUIRED)

# ── 4. Configure (MCU target setup functions) ───────────────────────────────

include("${_cmake_cache}/ch32fun-configure.cmake")

message(STATUS "ch32fun: framework at ${CH32FUN_FRAMEWORK_SOURCE_DIR}")
