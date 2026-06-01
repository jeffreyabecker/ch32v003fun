# ============================================================================
# ch32fun-toolchain.cmake
#
# Downloads (or locates) the xPack RISC-V GCC toolchain and configures CMake
# for bare-metal cross-compilation.
#
# This is an include() module, NOT a CMAKE_TOOLCHAIN_FILE.  It runs inside
# CMakeLists.txt processing so it can download archives and find programs.
# A true toolchain file would be loaded too early for that.
#
# Because it runs during project configuration, you must pass a makefile-
# based generator on the command line (Visual Studio is not supported):
#
#   cmake -B build -S . -G Ninja
#
# Usage:
#   cmake_minimum_required(VERSION 3.18)
#   include(cmake/ch32fun-toolchain.cmake)
#   project(myapp C ASM)
#
# Cache variables (set before include to override defaults):
#   CH32FUN_TOOLCHAIN_VERSION       — Toolchain version (default: 14.3.0-1)
#   CH32FUN_TOOLCHAIN_CACHE_DIR     — Download / extract cache (default: OS-appropriate)
#   CH32FUN_TOOLCHAIN_USE_SYSTEM    — Set ON to use a riscv-none-elf-gcc already on PATH
#
# On first run the toolchain archive (~70 MB) is downloaded from GitHub and
# extracted into the cache directory.  Subsequent runs use the cached copy.
# ============================================================================

include_guard(GLOBAL)

# ── 1. Cache variables ──────────────────────────────────────────────────────

if(NOT CH32FUN_TOOLCHAIN_VERSION)
    set(CH32FUN_TOOLCHAIN_VERSION "15.2.0-1" CACHE STRING
        "xPack RISC-V GCC version to download (requires >= 14.2.0-3 for rv32ec multilib)")
endif()

if(NOT CH32FUN_TOOLCHAIN_CACHE_DIR)
    # ── Resolve the global cache path (OS-specific) ──────────────────────
    if(WIN32 AND DEFINED ENV{LOCALAPPDATA})
        set(_global_cache "$ENV{LOCALAPPDATA}/riscv-xpack/toolchain")
    elseif(DEFINED ENV{XDG_CACHE_HOME})
        set(_global_cache "$ENV{XDG_CACHE_HOME}/riscv-xpack/toolchain")
    elseif(DEFINED ENV{HOME})
        set(_global_cache "$ENV{HOME}/.cache/riscv-xpack/toolchain")
    endif()

    # ── Prefer the global cache if it already holds a matching toolchain ──
    if(_global_cache AND EXISTS "${_global_cache}")
        file(GLOB _glob_dirs LIST_DIRECTORIES TRUE
            "${_global_cache}/xpack-riscv-none-elf-gcc-${CH32FUN_TOOLCHAIN_VERSION}*")
        foreach(_d IN LISTS _glob_dirs)
            if(WIN32)
                set(_test_gcc "${_d}/xpack-riscv-none-elf-gcc-${CH32FUN_TOOLCHAIN_VERSION}/bin/riscv-none-elf-gcc.exe")
            else()
                set(_test_gcc "${_d}/xpack-riscv-none-elf-gcc-${CH32FUN_TOOLCHAIN_VERSION}/bin/riscv-none-elf-gcc")
            endif()
            if(EXISTS "${_test_gcc}")
                set(_default_cache "${_global_cache}")
                message(STATUS "riscv-xpack: using global toolchain cache at ${_global_cache}")
                break()
            endif()
        endforeach()
    endif()

    # ── Otherwise, cache inside the build directory ──────────────────────
    if(NOT _default_cache)
        if(CMAKE_BINARY_DIR)
            set(_default_cache "${CMAKE_BINARY_DIR}/_toolchain")
        elseif(CMAKE_CURRENT_BINARY_DIR)
            set(_default_cache "${CMAKE_CURRENT_BINARY_DIR}/_toolchain")
        else()
            set(_default_cache "${_global_cache}")
        endif()
    endif()

    set(CH32FUN_TOOLCHAIN_CACHE_DIR "${_default_cache}" CACHE PATH
        "Cache directory for downloaded xPack RISC-V toolchains")
endif()

option(CH32FUN_TOOLCHAIN_USE_SYSTEM "Use riscv-none-elf-gcc already on PATH" OFF)

# ── 2. Internal helpers ─────────────────────────────────────────────────────

function(_riscv_xpack_detect_platform OUT_PLATFORM OUT_EXT)
    if(WIN32)
        set(_plat "win32-x64")
        set(_ext  "zip")
    elseif(APPLE)
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
            set(_plat "darwin-arm64")
        else()
            set(_plat "darwin-x64")
        endif()
        set(_ext "tar.gz")
    else()
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
            set(_plat "linux-arm64")
        elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^arm")
            set(_plat "linux-arm")
        else()
            set(_plat "linux-x64")
        endif()
        set(_ext "tar.gz")
    endif()
    set(${OUT_PLATFORM} "${_plat}" PARENT_SCOPE)
    set(${OUT_EXT}      "${_ext}"  PARENT_SCOPE)
endfunction()

function(_riscv_xpack_find_bindir OUT_DIR EXTRACT_ROOT VERSION)
    # Try the straightforward path first.
    set(_candidate "${EXTRACT_ROOT}/xpack-riscv-none-elf-gcc-${VERSION}/bin")
    if(EXISTS "${_candidate}")
        set(${OUT_DIR} "${_candidate}" PARENT_SCOPE)
        return()
    endif()

    # Fall back to a glob search in case the archive structure differs.
    file(GLOB _subdirs LIST_DIRECTORIES TRUE "${EXTRACT_ROOT}/*")
    foreach(_d IN LISTS _subdirs)
        if(IS_DIRECTORY "${_d}")
            if(WIN32)
                set(_gcc "${_d}/bin/riscv-none-elf-gcc.exe")
            else()
                set(_gcc "${_d}/bin/riscv-none-elf-gcc")
            endif()
            if(EXISTS "${_gcc}")
                set(${OUT_DIR} "${_d}/bin" PARENT_SCOPE)
                return()
            endif()
        endif()
    endforeach()
    set(${OUT_DIR} "" PARENT_SCOPE)
endfunction()

function(_riscv_xpack_download OUT_EXTRACT_DIR VERSION)
    _riscv_xpack_detect_platform(_plat _ext)
    set(_name    "xpack-riscv-none-elf-gcc-${VERSION}-${_plat}")
    set(_url     "https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v${VERSION}/${_name}.${_ext}")
    set(_archive "${CH32FUN_TOOLCHAIN_CACHE_DIR}/${_name}.${_ext}")
    set(_extract "${CH32FUN_TOOLCHAIN_CACHE_DIR}/${_name}")

    # Already cached?
    _riscv_xpack_find_bindir(_bindir "${_extract}" "${VERSION}")
    if(_bindir)
        message(STATUS "riscv-xpack: using cached toolchain at ${_bindir}")
        set(${OUT_EXTRACT_DIR} "${_extract}" PARENT_SCOPE)
        return()
    endif()

    # Download if we don't have the archive yet.
    if(NOT EXISTS "${_archive}")
        file(MAKE_DIRECTORY "${CH32FUN_TOOLCHAIN_CACHE_DIR}")
        message(STATUS "riscv-xpack: downloading xPack RISC-V GCC ${VERSION} …")
        message(STATUS "  → ${_url}")
        file(DOWNLOAD "${_url}" "${_archive}"
             SHOW_PROGRESS STATUS _dl_status TIMEOUT 900)
        list(GET _dl_status 0 _dl_code)
        if(NOT _dl_code EQUAL 0)
            list(GET _dl_status 1 _dl_msg)
            file(REMOVE "${_archive}")
            message(FATAL_ERROR "riscv-xpack: download failed (${_dl_code}): ${_dl_msg}")
        endif()
    endif()

    # Extract.
    message(STATUS "riscv-xpack: extracting ${_name}.${_ext} …")
    file(MAKE_DIRECTORY "${_extract}")
    file(ARCHIVE_EXTRACT INPUT "${_archive}" DESTINATION "${_extract}")

    # Verify the bindir exists inside the extracted tree.
    _riscv_xpack_find_bindir(_bindir "${_extract}" "${VERSION}")
    if(NOT _bindir)
        message(FATAL_ERROR
            "riscv-xpack: could not find riscv-none-elf-gcc in extracted archive.\n"
            "  Expected: ${_extract}/xpack-riscv-none-elf-gcc-${VERSION}/bin/")
    endif()
    message(STATUS "riscv-xpack: toolchain ready at ${_bindir}")
    set(${OUT_EXTRACT_DIR} "${_extract}" PARENT_SCOPE)
endfunction()

function(_riscv_xpack_find_system OUT_CC OUT_BINDIR)
    find_program(_cc NAMES riscv-none-elf-gcc)
    if(_cc)
        get_filename_component(_bindir "${_cc}" DIRECTORY)
        message(STATUS "riscv-xpack: found system toolchain at ${_cc}")
        set(${OUT_CC}     "${_cc}"     PARENT_SCOPE)
        set(${OUT_BINDIR} "${_bindir}" PARENT_SCOPE)
    else()
        set(${OUT_CC}     "" PARENT_SCOPE)
        set(${OUT_BINDIR} "" PARENT_SCOPE)
    endif()
endfunction()

# ── 3. Resolve the compiler ─────────────────────────────────────────────────

if(CH32FUN_TOOLCHAIN_USE_SYSTEM)
    _riscv_xpack_find_system(_cc _bindir)
    if(NOT _cc)
        message(FATAL_ERROR
            "riscv-xpack: CH32FUN_TOOLCHAIN_USE_SYSTEM=ON but riscv-none-elf-gcc "
            "was not found on PATH. Install the toolchain or unset this option.")
    endif()
else()
    _riscv_xpack_download(_extract_dir "${CH32FUN_TOOLCHAIN_VERSION}")
    _riscv_xpack_find_bindir(_bindir "${_extract_dir}" "${CH32FUN_TOOLCHAIN_VERSION}")
    if(NOT _bindir)
        message(FATAL_ERROR
            "riscv-xpack: internal error — could not locate bindir after download")
    endif()
    if(WIN32)
        set(_cc "${_bindir}/riscv-none-elf-gcc.exe")
    else()
        set(_cc "${_bindir}/riscv-none-elf-gcc")
    endif()
    if(NOT EXISTS "${_cc}")
        message(FATAL_ERROR "riscv-xpack: compiler not found at ${_cc}")
    endif()
endif()

# ── 4. Set up cross-compilation (must run BEFORE project()) ─────────────────
#
# ch32fun-toolchain.cmake is an include() module, not a true CMake
# toolchain file (which would be loaded via -DCMAKE_TOOLCHAIN_FILE).
# It runs as part of CMakeLists.txt processing, so it can download the
# compiler and find tools — things a true toolchain file cannot do.
#
# Because it runs during project configuration, the CMake generator has
# already been selected.  Visual Studio cannot cross-compile, so users
# must choose a makefile-based generator (Ninja is recommended):
#
#   cmake -B build -S . -G Ninja
#

# ── Reject unusable generators early ────────────────────────────────────

if(CMAKE_GENERATOR MATCHES "Visual Studio")
    message(FATAL_ERROR
        "\nch32fun: Visual Studio cannot cross-compile for RISC-V.\n"
        "  Use Ninja instead:\n\n"
        "    cmake -B build -S . -G Ninja\n\n"
        "  Or set CMAKE_GENERATOR=Ninja in your environment.")
endif()

# ── Cross-compilation variables (plain, for immediate effect) ───────────

set(CMAKE_SYSTEM_NAME            Generic)
set(CMAKE_SYSTEM_PROCESSOR       riscv)
set(CMAKE_C_COMPILER             "${_cc}")
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# ── Persist as cache entries (survive re-configure) ─────────────────────

set(CMAKE_SYSTEM_NAME            Generic CACHE STRING "Bare-metal target"    FORCE)
set(CMAKE_SYSTEM_PROCESSOR       riscv  CACHE STRING "RISC-V architecture"   FORCE)
set(CMAKE_C_COMPILER             "${_cc}" CACHE FILEPATH "RISC-V C compiler" FORCE)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY CACHE STRING ""            FORCE)

if(WIN32)
    set(_cxx "${_bindir}/riscv-none-elf-g++.exe")
else()
    set(_cxx "${_bindir}/riscv-none-elf-g++")
endif()
if(EXISTS "${_cxx}")
    set(CMAKE_CXX_COMPILER "${_cxx}")
    set(CMAKE_CXX_COMPILER "${_cxx}" CACHE FILEPATH "RISC-V C++ compiler" FORCE)
endif()

set(CMAKE_ASM_COMPILER "${_cc}")
set(CMAKE_ASM_COMPILER "${_cc}" CACHE FILEPATH "RISC-V ASM compiler" FORCE)

set(CMAKE_TRY_COMPILE_TARGET_TYPE   STATIC_LIBRARY CACHE STRING "" FORCE)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER CACHE STRING "" FORCE)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY  CACHE STRING "" FORCE)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY  CACHE STRING "" FORCE)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY  CACHE STRING "" FORCE)

message(STATUS "riscv-xpack: RISC-V ${CH32FUN_TOOLCHAIN_VERSION} — ${_cc}")
