# CH32Fun CMake Build Guide

## Quick Start

```powershell
# configure (must pass -G Ninja on Windows)
cmake -B build -S . -G Ninja

# build
cmake --build build
```

## Why `-G Ninja`?

The Visual Studio generator always uses MSVC as the C compiler.
RISC-V cross-compilation requires a makefile generator (Ninja,
MinGW Makefiles, Unix Makefiles).

## Differences From The Makefiles

- Uses CMake instead of GNU Make
- `MCU_PACKAGE` merged into `MCU` — pass the full package string
  (e.g. `MCU CH32V203F6P6`) or just the family name for defaults
- Auto-downloads toolchain and dependencies — clone and go
