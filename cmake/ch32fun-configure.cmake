# ============================================================================
# ch32fun-configure.cmake
#
# MCU-target configuration for the CH32Fun framework.  Include this after the
# toolchain + framework modules are loaded and after you've created a target
# with add_executable() / add_library():
#
#   include(cmake/ch32fun-toolchain.cmake)
#   project(myapp C ASM)
#   find_package(CH32Fun_Framework REQUIRED)
#   find_package(CH32Fun_Extras   REQUIRED)
#   add_executable(myapp main.c)
#   ch32fun_configure(TARGET myapp MCU CH32V003)
#
# Pass the full MCU package string to select a specific variant:
#
#   ch32fun_configure(TARGET myapp MCU CH32V203F6P6)
#
# Public functions:
#   ch32fun_configure(TARGET <name> [MCU <mcu>] [MEMORY_SPLIT <n>] [ENABLE_FPU ON|OFF])
#
# All arguments except TARGET are optional — they fall back to these
# cache variables when not passed:
#   CH32FUN_MCU            — Default MCU (e.g. CH32V003 or CH32V203F6P6)
#   CH32FUN_MEMORY_SPLIT   — Default memory split (CH32V307)
#   CH32FUN_ENABLE_FPU     — ON/OFF (CH32V307; default ON)
#
# This file is safe to include before any target is declared — it only
# defines functions and cache variables.
# ============================================================================

include_guard(GLOBAL)

# ── Cache variables ─────────────────────────────────────────────────────────

set(CH32FUN_NEWLIB "" CACHE PATH
    "Path to newlib includes (auto-detected from toolchain at configure time)")

set(CH32FUN_BASE_CFLAGS
    "-g" "-Os" "-flto" "-ffunction-sections" "-fdata-sections"
    "-fmessage-length=0" "-msmall-data-limit=8"
    CACHE STRING "Base CFLAGS for ch32fun")

set(CH32FUN_LIBGCC_PATH "" CACHE FILEPATH
    "Path to libgcc.a for the RISC-V toolchain.  Leave empty to auto-resolve
     from the ch32fun framework directory, or to download from GitHub.")

set(CH32FUN_MCU "" CACHE STRING
    "Default MCU for ch32fun_configure (e.g. CH32V003 or CH32V203F6P6)")

set(CH32FUN_MEMORY_SPLIT "" CACHE STRING
    "Default memory split for ch32fun_configure (CH32V307 only)")

set(CH32FUN_ENABLE_FPU "ON" CACHE STRING
    "Default FPU setting for ch32fun_configure (CH32V307 only; ON or OFF)")

# ── Internal helpers ────────────────────────────────────────────────────────

function(_ch32fun_gcc_at_least_13 OUT_VAR)
    execute_process(
        COMMAND "${CMAKE_C_COMPILER}" -dumpversion
        OUTPUT_VARIABLE _ver
        OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET
    )
    string(REGEX MATCH "^([0-9]+)" _major "${_ver}")
    if(_major GREATER_EQUAL 13)
        set(${OUT_VAR} TRUE PARENT_SCOPE)
    else()
        set(${OUT_VAR} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_ch32fun_str_contains OUT_VAR STR SUB)
    string(FIND "${STR}" "${SUB}" _pos)
    if(_pos GREATER_EQUAL 0)
        set(${OUT_VAR} TRUE PARENT_SCOPE)
    else()
        set(${OUT_VAR} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_ch32fun_find_tools)
    get_filename_component(_cc_dir  "${CMAKE_C_COMPILER}" DIRECTORY)
    get_filename_component(_cc_name "${CMAKE_C_COMPILER}" NAME_WE)
    string(REGEX REPLACE "-gcc$" "" _prefix "${_cc_name}")
    if(_prefix STREQUAL _cc_name)
        set(_prefix "${_cc_name}")
    endif()
    find_program(_OBJDUMP NAMES "${_prefix}-objdump" "${_cc_name}-objdump"
        HINTS "${_cc_dir}" DOC "objdump for RISC-V")
    find_program(_OBJCOPY NAMES "${_prefix}-objcopy" "${_cc_name}-objcopy"
        HINTS "${_cc_dir}" DOC "objcopy for RISC-V")
    if(NOT _OBJDUMP)
        set(_OBJDUMP "${_prefix}-objdump")
    endif()
    if(NOT _OBJCOPY)
        set(_OBJCOPY "${_prefix}-objcopy")
    endif()
    set(CH32FUN_OBJDUMP "${_OBJDUMP}" PARENT_SCOPE)
    set(CH32FUN_OBJCOPY "${_OBJCOPY}" PARENT_SCOPE)
endfunction()

# ── Resolve libgcc.a ────────────────────────────────────────────────────────

function(_ch32fun_resolve_libgcc OUT_LIBGCC_DIR OUT_LIBGCC_FILE)
    # 1 ── User-specified path
    if(CH32FUN_LIBGCC_PATH AND EXISTS "${CH32FUN_LIBGCC_PATH}")
        get_filename_component(_dir "${CH32FUN_LIBGCC_PATH}" DIRECTORY)
        message(STATUS "ch32fun: using libgcc.a from '${CH32FUN_LIBGCC_PATH}'")
        set(${OUT_LIBGCC_DIR}  "${_dir}" PARENT_SCOPE)
        set(${OUT_LIBGCC_FILE} "${CH32FUN_LIBGCC_PATH}" PARENT_SCOPE)
        return()
    endif()

    # 2 ── Look at the repo root (misc/ is one level up from the framework dir)
    get_filename_component(_repo_root "${CH32FUN_FRAMEWORK_SOURCE_DIR}" DIRECTORY)
    set(_candidate "${_repo_root}/misc/libgcc.a")
    if(EXISTS "${_candidate}")
        set(CH32FUN_LIBGCC_PATH "${_candidate}" CACHE FILEPATH "" FORCE)
        get_filename_component(_dir "${_candidate}" DIRECTORY)
        message(STATUS "ch32fun: found libgcc.a in framework: ${_candidate}")
        set(${OUT_LIBGCC_DIR}  "${_dir}" PARENT_SCOPE)
        set(${OUT_LIBGCC_FILE} "${_candidate}" PARENT_SCOPE)
        return()
    endif()

    # 3 ── Download from the ch32fun GitHub repo
    message(STATUS "ch32fun: libgcc.a not found — downloading from GitHub")
    get_filename_component(_repo_root "${CH32FUN_FRAMEWORK_SOURCE_DIR}" DIRECTORY)
    set(_dl_dir  "${_repo_root}/misc")
    set(_dl_file "${_dl_dir}/libgcc.a")
    file(MAKE_DIRECTORY "${_dl_dir}")
    file(DOWNLOAD
        "https://raw.githubusercontent.com/cnlohr/ch32fun/master/misc/libgcc.a"
        "${_dl_file}"
        SHOW_PROGRESS STATUS _dl_status TIMEOUT 120)
    list(GET _dl_status 0 _dl_code)
    if(NOT _dl_code EQUAL 0)
        list(GET _dl_status 1 _dl_msg)
        file(REMOVE "${_dl_file}")
        message(FATAL_ERROR "ch32fun: libgcc.a download failed (${_dl_code}): ${_dl_msg}")
    endif()

    set(CH32FUN_LIBGCC_PATH "${_dl_file}" CACHE FILEPATH "" FORCE)
    message(STATUS "ch32fun: downloaded libgcc.a to '${_dl_file}'")
    set(${OUT_LIBGCC_DIR}  "${_dl_dir}"  PARENT_SCOPE)
    set(${OUT_LIBGCC_FILE} "${_dl_file}" PARENT_SCOPE)
endfunction()

# ── ch32fun_configure() ─────────────────────────────────────────────────────

function(ch32fun_configure)
    set(_options )
    set(_oneValueArgs TARGET MCU MEMORY_SPLIT ENABLE_FPU)
    set(_multiValueArgs )
    cmake_parse_arguments(_arg "" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})

    # ── Validate / resolve inputs ───────────────────────────────────────

    if(NOT _arg_TARGET)
        message(FATAL_ERROR "ch32fun_configure: TARGET is required")
    endif()
    if(NOT _arg_MCU)
        if(CH32FUN_MCU)
            set(_arg_MCU "${CH32FUN_MCU}")
        else()
            message(FATAL_ERROR "ch32fun_configure: MCU is required "
                                "(pass MCU <mcu> or set CH32FUN_MCU)")
        endif()
    endif()
    if(NOT _arg_MEMORY_SPLIT AND CH32FUN_MEMORY_SPLIT)
        set(_arg_MEMORY_SPLIT "${CH32FUN_MEMORY_SPLIT}")
    endif()
    if(NOT _arg_ENABLE_FPU AND CH32FUN_ENABLE_FPU)
        set(_arg_ENABLE_FPU "${CH32FUN_ENABLE_FPU}")
    endif()
    if(NOT TARGET ${_arg_TARGET})
        message(FATAL_ERROR
            "ch32fun_configure: target '${_arg_TARGET}' does not exist. "
            "Create it with add_executable() or add_library() first.")
    endif()

    if(NOT CH32FUN_FRAMEWORK_FOUND)
        message(FATAL_ERROR
            "ch32fun_configure: CH32Fun framework not found. "
            "Call find_package(CH32Fun_Framework REQUIRED) first.")
    endif()

    # ── Attach the ch32fun.c source ─────────────────────────────────────

    set(_ch32fun_c "${CH32FUN_FRAMEWORK_SOURCE_DIR}/ch32fun.c")
    if(NOT EXISTS "${_ch32fun_c}")
        message(FATAL_ERROR
            "ch32fun_configure: ch32fun.c not found at '${_ch32fun_c}'")
    endif()
    target_sources(${_arg_TARGET} PRIVATE "${_ch32fun_c}")

    # ── Defaults ────────────────────────────────────────────────────────

    if(_arg_ENABLE_FPU STREQUAL "")
        set(_arg_ENABLE_FPU "ON")
    endif()

    set(_mcu    "${_arg_MCU}")
    set(_pkg    "${_arg_MCU}")
    set(_msplit "${_arg_MEMORY_SPLIT}")

    message(STATUS "ch32fun: configuring ${_arg_TARGET} for ${_mcu}")

    # ====================================================================
    # MCU FAMILY DETECTION
    # ====================================================================

    _ch32fun_str_contains(_is_v00x "${_mcu}" "CH32V00")
    if(_is_v00x)
        set(_mcu_package 1)
        _ch32fun_gcc_at_least_13(_gcc13)

        _ch32fun_str_contains(_is_v003 "${_mcu}" "CH32V003")
        _ch32fun_str_contains(_is_v002 "${_mcu}" "CH32V002")
        _ch32fun_str_contains(_is_v004 "${_mcu}" "CH32V004")
        _ch32fun_str_contains(_is_v005 "${_mcu}" "CH32V005")
        _ch32fun_str_contains(_is_v006 "${_mcu}" "CH32V006")
        _ch32fun_str_contains(_is_v007 "${_mcu}" "CH32V007")

        if(_is_v003)
            set(_cflags_arch "-march=rv32ec" "-mabi=ilp32e")
            set(_mcu_ld 0)
        elseif(_is_v002)
            if(_gcc13)
                set(_cflags_arch "-march=rv32ec_zmmul" "-mabi=ilp32e" "-DCH32V00x=1")
            else()
                set(_cflags_arch "-march=rv32ec" "-mabi=ilp32e" "-DCH32V00x=1")
            endif()
            set(_mcu_ld 5)
        elseif(_is_v004)
            if(_gcc13)
                set(_cflags_arch "-march=rv32ec_zmmul" "-mabi=ilp32e" "-DCH32V00x=1")
            else()
                set(_cflags_arch "-march=rv32ec" "-mabi=ilp32e" "-DCH32V00x=1")
            endif()
            set(_mcu_ld 6)
        elseif(_is_v005 OR _is_v006 OR _is_v007)
            if(_gcc13)
                set(_cflags_arch "-march=rv32ec_zmmul" "-mabi=ilp32e" "-DCH32V00x=1")
            else()
                set(_cflags_arch "-march=rv32ec" "-mabi=ilp32e" "-DCH32V00x=1")
            endif()
            set(_mcu_ld 7)
        else()
            message(FATAL_ERROR "Unknown MCU in CH32V00x family: ${_mcu}")
        endif()

        list(APPEND _cflags_arch "-D${_mcu}")
        # GCC LTO is broken on rv32ec across all xPack versions (14.3 – 15.2)
        list(APPEND _cflags_arch "-fno-lto")
        _ch32fun_resolve_libgcc(_libgcc_dir _libgcc_file)
        target_link_options(${_arg_TARGET} PRIVATE "-L${_libgcc_dir}" "-lgcc")

    else()
        _ch32fun_str_contains(_is_v10x "${_mcu}" "CH32V10")
        if(_is_v10x)
            set(_cflags_arch "-march=rv32imac" "-mabi=ilp32" "-DCH32V10x=1")
            _ch32fun_str_contains(_has_R8 "${_pkg}" "R8")
            _ch32fun_str_contains(_has_C8 "${_pkg}" "C8")
            _ch32fun_str_contains(_has_C6 "${_pkg}" "C6")
            if(_has_R8 OR _has_C8)
                set(_mcu_package 1)
            elseif(_has_C6)
                set(_mcu_package 2)
            endif()
            if(NOT DEFINED _mcu_package)
                set(_mcu_package 1)
            endif()
            set(_mcu_ld 1)
        else()
            _ch32fun_str_contains(_is_x03x "${_mcu}" "CH32X03")
            if(_is_x03x)
                set(_cflags_arch "-march=rv32imac" "-mabi=ilp32" "-DCH32X03x=1")
                set(_mcu_package 1)
                set(_mcu_ld 4)
            else()
                _ch32fun_str_contains(_is_v20x "${_mcu}" "CH32V20")
                if(_is_v20x)
                    set(_cflags_arch "-march=rv32imac" "-mabi=ilp32" "-DCH32V20x=1")
                    _ch32fun_str_contains(_is_203RB "${_pkg}" "203RB")
                    _ch32fun_str_contains(_is_208   "${_pkg}" "208")
                    _ch32fun_str_contains(_has_F8   "${_pkg}" "F8")
                    _ch32fun_str_contains(_has_G8   "${_pkg}" "G8")
                    _ch32fun_str_contains(_has_K8   "${_pkg}" "K8")
                    _ch32fun_str_contains(_has_C8   "${_pkg}" "C8")
                    _ch32fun_str_contains(_has_F6   "${_pkg}" "F6")
                    _ch32fun_str_contains(_has_G6   "${_pkg}" "G6")
                    _ch32fun_str_contains(_has_K6   "${_pkg}" "K6")
                    _ch32fun_str_contains(_has_C6   "${_pkg}" "C6")
                    _ch32fun_str_contains(_has_RB   "${_pkg}" "RB")
                    _ch32fun_str_contains(_has_GB   "${_pkg}" "GB")
                    _ch32fun_str_contains(_has_CB   "${_pkg}" "CB")
                    _ch32fun_str_contains(_has_WB   "${_pkg}" "WB")
                    if(_is_203RB)
                        list(APPEND _cflags_arch "-DCH32V20x_D8")
                    elseif(_is_208)
                        list(APPEND _cflags_arch "-DCH32V20x_D8W")
                        set(_mcu_package 3)
                    else()
                        list(APPEND _cflags_arch "-DCH32V20x_D6")
                    endif()
                    if(NOT _is_208)
                        if(_has_F8 OR _has_G8 OR _has_K8 OR _has_C8)
                            set(_mcu_package 1)
                        elseif(_has_F6 OR _has_G6 OR _has_K6 OR _has_C6)
                            set(_mcu_package 2)
                        elseif(_has_RB OR _has_GB OR _has_CB OR _has_WB)
                            set(_mcu_package 3)
                        endif()
                    endif()
                    if(NOT DEFINED _mcu_package)
                        set(_mcu_package 2)
                    endif()
                    set(_mcu_ld 2)
                else()
                    _ch32fun_str_contains(_is_v30x "${_mcu}" "CH32V30")
                    if(_is_v30x)
                        if(NOT _msplit)
                            set(_msplit "3")
                        endif()
                        if(_arg_ENABLE_FPU)
                            set(_cflags_arch "-march=rv32imafc" "-mabi=ilp32f")
                        else()
                            set(_cflags_arch "-march=rv32imac" "-mabi=ilp32" "-DDISABLED_FLOAT")
                        endif()
                        list(APPEND _cflags_arch "-DCH32V30x=1" "-DTARGET_MCU_MEMORY_SPLIT=${_msplit}")
                        _ch32fun_str_contains(_has_RC "${_pkg}" "RC")
                        _ch32fun_str_contains(_has_VC "${_pkg}" "VC")
                        _ch32fun_str_contains(_has_WC "${_pkg}" "WC")
                        _ch32fun_str_contains(_has_CB "${_pkg}" "CB")
                        _ch32fun_str_contains(_has_FB "${_pkg}" "FB")
                        _ch32fun_str_contains(_has_RB "${_pkg}" "RB")
                        if(_has_RC OR _has_VC OR _has_WC)
                            set(_mcu_package 1)
                        elseif(_has_CB OR _has_FB OR _has_RB)
                            set(_mcu_package 2)
                        endif()
                        if(NOT DEFINED _mcu_package)
                            set(_mcu_package 1)
                        endif()
                        _ch32fun_str_contains(_is_303 "${_pkg}" "303")
                        if(_is_303)
                            list(APPEND _cflags_arch "-DCH32V30x_D8")
                        else()
                            list(APPEND _cflags_arch "-DCH32V30x_D8C")
                        endif()
                        set(_mcu_ld 3)
                    else()
                        _ch32fun_str_contains(_is_ch57 "${_mcu}" "CH57")
                        if(_is_ch57)
                            set(_cflags_arch "-march=rv32imac" "-mabi=ilp32" "-DCH57x=1")
                            _ch32fun_str_contains(_has_570 "${_pkg}" "570")
                            _ch32fun_str_contains(_has_571 "${_pkg}" "571")
                            _ch32fun_str_contains(_has_572 "${_pkg}" "572")
                            _ch32fun_str_contains(_has_573 "${_pkg}" "573")
                            if(_has_570)
                                set(_mcu_package 0)
                            elseif(_has_571)
                                set(_mcu_package 1)
                            elseif(_has_572)
                                set(_mcu_package 2)
                            elseif(_has_573)
                                set(_mcu_package 3)
                            endif()
                            if(NOT DEFINED _mcu_package)
                                set(_mcu_package 0)
                            endif()
                            list(APPEND _cflags_arch "-DMCU_PACKAGE=${_mcu_package}")
                            _ch32fun_str_contains(_has_D "${_pkg}" "D")
                            _ch32fun_str_contains(_has_Q "${_pkg}" "Q")
                            _ch32fun_str_contains(_has_R "${_pkg}" "R")
                            _ch32fun_str_contains(_has_E "${_pkg}" "E")
                            if(_has_D)
                                list(APPEND _cflags_arch "-DCH57xD")
                            elseif(_has_Q)
                                list(APPEND _cflags_arch "-DCH57xQ")
                            elseif(_has_R)
                                list(APPEND _cflags_arch "-DCH57xR")
                            elseif(_has_E)
                                list(APPEND _cflags_arch "-DCH57xE")
                            endif()
                            set(_mcu_ld 10)
                        else()
                            _ch32fun_str_contains(_is_ch58 "${_mcu}" "CH58")
                            if(_is_ch58)
                                set(_cflags_arch "-march=rv32imac" "-mabi=ilp32" "-DCH58x=1")
                                _ch32fun_str_contains(_has_582 "${_pkg}" "582")
                                _ch32fun_str_contains(_has_583 "${_pkg}" "583")
                                _ch32fun_str_contains(_has_584 "${_pkg}" "584")
                                _ch32fun_str_contains(_has_585 "${_pkg}" "585")
                                if(_has_582)
                                    set(_mcu_package 2)
                                elseif(_has_583)
                                    set(_mcu_package 3)
                                elseif(_has_584)
                                    set(_mcu_package 4)
                                elseif(_has_585)
                                    set(_mcu_package 5)
                                endif()
                                if(NOT DEFINED _mcu_package)
                                    set(_mcu_package 2)
                                endif()
                                list(APPEND _cflags_arch "-DMCU_PACKAGE=${_mcu_package}")
                                _ch32fun_str_contains(_has_D "${_pkg}" "D")
                                _ch32fun_str_contains(_has_F_pkg "${_pkg}" "F")
                                _ch32fun_str_contains(_has_M "${_pkg}" "M")
                                if(_has_D)
                                    list(APPEND _cflags_arch "-DCH58xD")
                                elseif(_has_F_pkg)
                                    list(APPEND _cflags_arch "-DCH58xF")
                                elseif(_has_M)
                                    list(APPEND _cflags_arch "-DCH58xM")
                                endif()
                                set(_mcu_ld 8)
                            else()
                                _ch32fun_str_contains(_is_ch59 "${_mcu}" "CH59")
                                if(_is_ch59)
                                    set(_cflags_arch "-march=rv32imac" "-mabi=ilp32" "-DCH59x=1")
                                    _ch32fun_str_contains(_has_591 "${_pkg}" "591")
                                    _ch32fun_str_contains(_has_592 "${_pkg}" "592")
                                    if(_has_591)
                                        set(_mcu_package 1)
                                    elseif(_has_592)
                                        set(_mcu_package 2)
                                    endif()
                                    if(NOT DEFINED _mcu_package)
                                        set(_mcu_package 2)
                                    endif()
                                    list(APPEND _cflags_arch "-DMCU_PACKAGE=${_mcu_package}")
                                    _ch32fun_str_contains(_has_D "${_pkg}" "D")
                                    _ch32fun_str_contains(_has_F_pkg "${_pkg}" "F")
                                    if(_has_D)
                                        list(APPEND _cflags_arch "-DCH59xD")
                                    elseif(_has_F_pkg)
                                        list(APPEND _cflags_arch "-DCH59xF")
                                    endif()
                                    set(_mcu_ld 9)
                                else()
                                    message(FATAL_ERROR "ch32fun_configure: Unknown MCU '${_mcu}'")
                                endif()  # CH59x
                            endif()  # CH58x
                        endif()  # CH57x
                    endif()  # CH32V30x
                endif()  # CH32V20x
            endif()  # CH32X03x
        endif()  # CH32V10x
    endif()  # CH32V00x

    # ====================================================================
    # Linker script generation
    # ====================================================================
    set(_ld_template "${CH32FUN_FRAMEWORK_SOURCE_DIR}/ch32fun.ld")
    if(NOT EXISTS "${_ld_template}")
        message(FATAL_ERROR "ch32fun: linker template not found: ${_ld_template}")
    endif()
    if(NOT _msplit)
        set(_msplit "")
    endif()
    set(_gen_ld "${CMAKE_CURRENT_BINARY_DIR}/generated_${_pkg}_${_msplit}.ld")

    add_custom_command(TARGET ${_arg_TARGET} PRE_LINK
        COMMAND "${CMAKE_C_COMPILER}"
                -E -P -x c
                "-DTARGET_MCU=${_mcu}"
                "-DMCU_PACKAGE=${_mcu_package}"
                "-DTARGET_MCU_LD=${_mcu_ld}"
                "-DTARGET_MCU_MEMORY_SPLIT=${_msplit}"
                "${_ld_template}"
                -o "${_gen_ld}"
        BYPRODUCTS "${_gen_ld}"
        COMMENT "Generating linker script for ${_mcu} (pkg=${_pkg})"
    )

    # ====================================================================
    # Resolve newlib from the toolchain
    # ====================================================================
    if(NOT CH32FUN_NEWLIB)
        get_filename_component(_cc_bindir "${CMAKE_C_COMPILER}" DIRECTORY)
        set(_newlib_candidate "${_cc_bindir}/../riscv-none-elf/include")
        if(EXISTS "${_newlib_candidate}")
            set(CH32FUN_NEWLIB "${_newlib_candidate}" CACHE PATH
                "Path to newlib includes (auto-detected from toolchain)" FORCE)
        else()
            set(CH32FUN_NEWLIB "/usr/include/newlib" CACHE PATH
                "Path to newlib includes (fallback; set manually if incorrect)" FORCE)
        endif()
    endif()

    # ====================================================================
    # Compile flags
    # ====================================================================
    target_compile_options(${_arg_TARGET} PRIVATE
        ${CH32FUN_BASE_CFLAGS}
        ${_cflags_arch}
        "--specs=nano.specs"
        "-static-libgcc"
        "-I${CH32FUN_NEWLIB}"
        "-I${CH32FUN_FRAMEWORK_INCLUDE_DIR}"
        "-nostdlib"
        "-I${CMAKE_CURRENT_SOURCE_DIR}"
        "-Wall"
    )
    if(CH32FUN_EXTRAS_FOUND)
        target_compile_options(${_arg_TARGET} PRIVATE
            "-I${CH32FUN_EXTRAS_INCLUDE_DIR}")
    endif()
    if(CMAKE_BUILD_TYPE MATCHES "Debug")
        target_compile_options(${_arg_TARGET} PRIVATE "-DFUNCONF_DEBUG=1")
    endif()

    # ====================================================================
    # Link flags
    # ====================================================================
    target_link_options(${_arg_TARGET} PRIVATE
        "-nostdlib"
        "-T" "${_gen_ld}"
        "-Wl,--gc-sections"
        "-Wl,--print-memory-usage"
        "-Wl,-Map=${_arg_TARGET}.map"
        "-lgcc"
    )

    # ====================================================================
    # Apply to target
    # ====================================================================
    target_compile_options(${_arg_TARGET} PRIVATE
        $<$<COMPILE_LANGUAGE:CXX>:-fno-rtti>
        $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions>
    )
    set_target_properties(${_arg_TARGET} PROPERTIES SUFFIX ".elf")

    # ====================================================================
    # Post-build: .bin, .hex, .lst
    # ====================================================================
    _ch32fun_find_tools()
    add_custom_command(TARGET ${_arg_TARGET} POST_BUILD
        COMMAND "${CH32FUN_OBJDUMP}" -S "$<TARGET_FILE:${_arg_TARGET}>" > "${_arg_TARGET}.lst"
        COMMAND "${CH32FUN_OBJCOPY}" -O binary "$<TARGET_FILE:${_arg_TARGET}>" "${_arg_TARGET}.bin"
        COMMAND "${CH32FUN_OBJCOPY}" -O ihex "$<TARGET_FILE:${_arg_TARGET}>" "${_arg_TARGET}.hex"
        COMMENT "Generating .lst .bin .hex for ${_arg_TARGET}"
    )
endfunction()
