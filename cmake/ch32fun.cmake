# ============================================================================
# ch32fun.cmake
#
# Umbrella include — pulls in the entire ch32fun CMake toolchain in one call.
# Include this *before* project() in your CMakeLists.txt:
#
#   cmake_minimum_required(VERSION 3.18)
#   include(cmake/ch32fun.cmake)
#   project(myapp C ASM)
#   add_executable(myapp main.c)
#   ch32fun_configure(TARGET myapp MCU CH32V003)
#
# This single include does the following:
#   1. Downloads and configures the xPack RISC-V GCC toolchain.
#   2. Locates (or fetches) the CH32Fun framework from GitHub.
#   3. Locates the extralibs/ helper module within the framework.
#   4. Loads the ch32fun_configure() function for MCU target setup.
#
# If you need finer control, include the individual modules instead:
#   - cmake/ch32fun-toolchain.cmake
#   - cmake/ch32fun-framework.cmake
#   - cmake/ch32fun-extras.cmake
#   - cmake/ch32fun-configure.cmake
# ============================================================================

include_guard(GLOBAL)

# ── 1. Toolchain ────────────────────────────────────────────────────────────

include("${CMAKE_CURRENT_LIST_DIR}/ch32fun-toolchain.cmake")

# ── 2. Framework (locate or FetchContent) ───────────────────────────────────

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")


# ── 4. Configure (MCU target setup functions) ───────────────────────────────

include("${CMAKE_CURRENT_LIST_DIR}/ch32fun-configure.cmake")

message(STATUS "ch32fun: framework at ${CH32FUN_FRAMEWORK_SOURCE_DIR}")
