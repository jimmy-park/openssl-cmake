# openssl-cmake

Build OpenSSL in parallel within CMake

## Features

- Support versions from `1.1.0h` to the latest `3.0` series
- Detect major platforms
- Download the source code only once (thanks [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake)!)
- Don't reconfigure if same options are used
- Automatically use the maximum number of processors
- Reduce rebuild time using [ccache](https://github.com/ccache/ccache)

## Prerequisites

### Requirements

- CMake 3.24+ (due to `FetchContent_Declare(OVERRIDE_FIND_PACKAGE)`)
- OpenSSL build tools [Link](https://github.com/openssl/openssl/blob/master/INSTALL.md#prerequisites)
  - Make implementation
  - Perl 5
  - ANSI C compiler
  - NASM (Windows only)
- ccache (optional)

### Linux

Install CMake from [official website](https://cmake.org/download/) or [Snapcraft](https://snapcraft.io/docs/installing-snapd)

```sh
sudo snap install cmake --classic
sudo apt install -y build-essential perl ninja-build ccache
```

### macOS

Install packages from [Homebrew](https://brew.sh/)

```sh
brew install cmake perl ccache
xcode-select --install
```

### Windows

You need to use Visual Studio to build OpenSSL in Windows

[Chocolatey](https://chocolatey.org/install) is recommended to install required packages

```sh
# Powershell (run as administrator)
choco install -y cmake jom strawberryperl nasm ccache --installargs 'ADD_CMAKE_TO_PATH=System'

# Append "C:\Program Files\NASM" to the PATH environment variable
# or run this code
[Environment]::SetEnvironmentVariable("PATH", "$ENV:PATH;C:\Program Files\NASM", "USER")
```

## Configure Options

| Option                        | Type      | Default       | Description                                |
| ---                           | ---       | ---           | ---                                        |
| `OPENSSL_BUILD_PARALLEL`      | bool      | `ON`          | Enable parallel build                      |
| `OPENSSL_CONFIGURE_OPTIONS`   | list      | `no-tests`    | Use OpenSSL's Configure options            |
| `OPENSSL_CONFIGURE_VERBOSE`   | bool      | `OFF`         | Print configuration logs                   |
| `OPENSSL_INSTALL_LIBS`        | bool      | `OFF`         | Run `make install`-like command internally |
| `OPENSSL_USE_CCACHE`          | bool      | `OFF`         | Force to check ccache installation         |
| `OPENSSL_TARGET_PLATFORM`     | string    | `(undefined)` | Use OpenSSL's Configure target             |
| `OPENSSL_TARGET_VERSION`      | string    | `3.0.7`       | Use the latest 3.0 series                  |

### Notes

- `OPENSSL_BUILD_PARALLEL`
  - Detect the number of processors using `ProcessorCount` module
- `OPENSSL_CONFIGURE_OPTIONS`
  - `--prefix` is used internally (set to `${CMAKE_INSTALL_PREFIX}/OpenSSL-${OPENSSL_TARGET_VERSION}`)
  - `no-shared` determines the type of library (`SHARED|STATIC`)
  - `no-tests` isn't supported in the 1.1.0 series
- `OPENSSL_USE_CCACHE`
  - When ccache is installed correctly, it will be used even if `OPENSSL_USE_CCACHE` is `OFF`
- `OPENSSL_TARGET_PLATFORM`
  - Detect target platform if `OPENSSL_TARGET_PLATFORM` isn't defined
  - It is needed to set `OPENSSL_TARGET_PLATFORM` explicitly on some platforms
- `CPM_SOURCE_CACHE`
  - Set to `/path/to/cache` to reuse downloaded source code

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
set(OPENSSL_TARGET_VERSION 3.0.7)
set(OPENSSL_TARGET_PLATFORM VC-WIN64A)
set(OPENSSL_CONFIGURE_OPTIONS no-shared no-tests)
set(OPENSSL_USE_CCACHE ON)

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

#### Using [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake)

```CMake
set(CPM_SOURCE_CACHE /path/to/cache)

CPMAddPackage(
    NAME openssl-cmake
    URL https://github.com/jimmy-park/openssl-cmake/archive/main.zip
    OPTIONS
    "OPENSSL_TARGET_VERSION 3.0.7"
    "OPENSSL_TARGET_PLATFORM VC-WIN64A"
    "OPENSSL_CONFIGURE_OPTIONS no-shared\\\\;no-tests"
    "OPENSSL_USE_CCACHE ON"
)
```
