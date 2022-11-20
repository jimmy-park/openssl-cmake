# openssl-cmake

Build OpenSSL in parallel within CMake

Support OpenSSL versions from `1.1.0h` to the latest `3.0` series

## Prerequisites


### Requirements

- CMake 3.24+ (due to `FetchContent_Declare(OVERRIDE_FIND_PACKAGE)`)
- Some OpenSSL build tools [Link](https://github.com/openssl/openssl/blob/master/INSTALL.md#prerequisites)
  - Make implementation
  - Perl 5
  - ANSI C compiler
  - NASM (Windows only)

### Windows

You need to use Visual Studio to build OpenSSL in Windows

[Chocolatey](https://chocolatey.org/install) is recommended to install required packages

```sh
# Powershell (run as administrator)
choco install -y cmake jom strawberryperl nasm --installargs 'ADD_CMAKE_TO_PATH=System'

# Append "C:\Program Files\NASM" to the PATH environment variable
# or run this code
[Environment]::SetEnvironmentVariable("PATH", "$ENV:PATH;C:\Program Files\NASM", "USER")
```

## Configure Options

| Option                        | Type      | Default           | Mandatory?    |
| ---                           | :---:     | :---:             | :---:         |
| `OPENSSL_CONFIGURE_OPTIONS`   | list      | no-tests          | no            |
| `OPENSSL_CONFIGURE_VERBOSE`   | bool      | OFF               | no            |
| `OPENSSL_PARALLEL_BUILD`      | bool      | ON                | no            |
| `OPENSSL_TARGET_PLATFORM`     | string    | (undefined)       | yes           |
| `OPENSSL_TARGET_VERSION`      | string    | latest 3.0 series | no            |

## Usage

### Build

```sh
git clone https://github.com/jimmy-park/openssl-cmake
cd openssl-cmake

# List all presets
cmake --list-presets all

# Use a configure preset
cmake --preset windows-x64

# Use a build preset
# <configure-preset>-[clean|install]
cmake --build --preset windows-x64
```

### Integration

```CMake
include(FetchContent)

# Set options before FetchContent_MakeAvailable()
set(OPENSSL_TARGET_VERSION "3.0.7")
set(OPENSSL_TARGET_PLATFORM "VC-WIN64A")
set(OPENSSL_CONFIGURE_OPTIONS no-shared no-tests)

FetchContent_Declare(
    openssl-cmake
    URL https://github.com/jimmy-park/openssl-cmake/archive/main.zip
)

# This line must be preceded before find_package(OpenSSL REQUIRED)
FetchContent_MakeAvailable(openssl-cmake)

# Use same targets as FindOpenSSL module
add_executable(main main.cpp)
target_link_libraries(main PRIVATE
    OpenSSL::SSL
    OpenSSL::Crypto
    $<$<CXX_COMPILER_ID:MSVC>:OpenSSL::applink>
)
```

### Caveats

- `--prefix` option in `OPENSSL_CONFIGURE_OPTIONS` will be ignored and used internally
  - `--prefix` is set to `${CMAKE_INSTALL_PREFIX}/OpenSSL-${OPENSSL_TARGET_VERSION}`
  - `cmake --build --target install` or `cmake --build --preset <preset>-install` will use this path
