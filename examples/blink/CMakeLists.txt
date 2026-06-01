cmake_minimum_required(VERSION 3.18)

include(../../cmake/ch32fun.cmake)

# Use the local ch32fun framework (this repo's ch32fun/ directory)
set(CH32FUN_FRAMEWORK_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../ch32fun")
find_package(CH32Fun_Framework REQUIRED)

project(blink C ASM)

add_executable(blink blink.c)
ch32fun_configure(TARGET blink)
