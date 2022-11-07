# openssl-cmake

Build OpenSSL in parallel within CMake

## Requirements

- CMake 3.24 or above

## Usage

### Build

```sh
git clone https://github.com/jimmy-park/openssl-cmake
cd openssl-cmake

# List all presets
cmake --list-presets all

# Use a configure preset
cmake --preset windows-x64

# TODO
# Use a build preset
# <configure-preset>-[clean|install]
cmake --build --preset windows-x64
```

### Integration

```CMake
include(FetchContent)

# Set options before FetchContent_MakeAvailable()
set(OPENSSL_PARALLEL_BUILD ON)
set(OPENSSL_TARGET_VERSION "3.0.7")
set(OPENSSL_TARGET_PLATFORM "VC-WIN64A")
set(OPENSSL_CONFIGURE_OPTIONS no-shared no-tests)

FetchContent_Declare(
    openssl-cmake
    URL https://github.com/jimmy-park/openssl-cmake/archive/main.zip
)

# This line must be preceeded find_package(OpenSSL REQUIRED)
FetchContent_MakeAvailable(openssl-cmake)

# TODO
# Use same targets as FindOpenSSL module
add_executable(main main.cpp)
target_link_libraries(main PRIVATE
    OpenSSL::SSL
    OpenSSL::Crypto
    $<$<CXX_COMPILER_ID:MSVC>:OpenSSL::applink>
)
```
