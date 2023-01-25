# openssl-cmake

Build OpenSSL in parallel within CMake

## Features

- Support both `1.1.1` and `3.0` series of OpenSSL
- Detect major platforms
- Download the source code only once (thanks [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake)!)
- Don't reconfigure if same options are used
- Automatically use the maximum number of processors
- Reduce rebuild time using [ccache](https://github.com/ccache/ccache)
- Override the `FindOpenSSL` module (no need to change CMake code)

## Benchmarks

| | Time | Speed |
| --- | ---: | ---: |
| Sequential                  | 135 s  | 1.00 x |
| Sequential w/ ccache (cold) | 580 s  | 0.23 x |
| Sequential w/ ccache (warm) | 95 s   | 1.42 x |
| Parallel                    | 26 s   | 5.19 x |
| Parallel w/ ccache (cold)   | 126 s  | 1.07 x |
| Parallel w/ ccache (warm)   | 16 s   | **8.44 x** |

- **OS** : Windows 10 22H2
- **CPU** : AMD Ryzen 5 3600 6-Core Processor 3.60 GHz
- **RAM** : 16 GB
- **Storage** : Samsung SSD 860 EVO
- **Compiler** : MSVC 14.34
- **Configuration**
  - OpenSSL 3.0.7 (`VC-WIN64A`, `no-tests`, `no-asm`, `no-makedepend`, `no-shared`)
  - ccache 4.7.4 (default options)
- **Note**
  - MSVC with ccache has much longer build time on first build

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

## CMake Options

| Option                      | Type   | Default       | Description                                      |
| ---                         | ---    | ---           | ---                                              |
| `OPENSSL_BUILD_TARGET`      | string | `build_libs`  | Makefile target for build                        |
| `OPENSSL_BUILD_VERBOSE`     | bool   | `OFF`         | Enable verbose output from build                 |
| `OPENSSL_CONFIGURE_OPTIONS` | list   | `(undefined)` | Use OpenSSL's Configure options                  |
| `OPENSSL_CONFIGURE_VERBOSE` | bool   | `OFF`         | Enable verbose output from configuration         |
| `OPENSSL_ENABLE_PARALLEL`   | bool   | `ON`          | Enable parallel build and test                   |
| `OPENSSL_INSTALL`           | bool   | `OFF`         | Install OpenSSL components                       |
| `OPENSSL_INSTALL_CERT`      | bool   | `OFF`         | Install `cert.pem` to the `openssldir` directory |
| `OPENSSL_INSTALL_TARGET`    | string | `install_dev` | Makefile target for install                      |
| `OPENSSL_PATCH`             | file   | `(undefined)` | Apply a patch to OpenSSL source                  |
| `OPENSSL_TARGET_PLATFORM`   | string | `(undefined)` | Use OpenSSL's Configure target                   |
| `OPENSSL_TARGET_VERSION`    | string | `3.0.7`       | Use the latest 3.0 series                        |
| `OPENSSL_TEST`              | bool   | `OFF`         | Enable testing and build OpenSSL self tests      |
| `OPENSSL_USE_CCACHE`        | bool   | `ON`          | Use ccache if available                          |

### Notes

- `OPENSSL_CONFIGURE_OPTIONS`
  - `no-shared` determines the type of library (`SHARED or STATIC`)
  - `no-tests` is added when `OPENSSL_TEST` is `OFF`
- `OPENSSL_ENABLE_PARALLEL`
  - Detect the number of processors using `ProcessorCount` module
- `OPENSSL_PATCH`
  - Since OpenSSL source is distributed with `LF`, the patch file must also be `LF`
- `OPENSSL_TARGET_PLATFORM`
  - Detect target platform if `OPENSSL_TARGET_PLATFORM` isn't defined
  - It is needed to set `OPENSSL_TARGET_PLATFORM` explicitly on some platforms
- `OPENSSL_USE_CCACHE`
  - Whenever you change this option, perform a fresh configuration (or just delete `CMakeCache.txt`)
- `CPM_SOURCE_CACHE`
  - Set to `/path/to/cache` to reuse downloaded source code

## Usage

### Build

```sh
# List all presets
cmake --list-presets all

# Use a configure preset
cmake --preset windows-x64

# Use a build preset
# <configure-preset>-[clean|install]
cmake --build --preset windows-x64

# Use a test preset
ctest --preset windows-x64

# Use a build preset for install
# equal to `cmake --build --preset windows-x64 --target install`
cmake --build --preset windows-x64-install
```

### Integration

```CMake
include(FetchContent)

# Set options before FetchContent_MakeAvailable()
set(OPENSSL_TARGET_VERSION 3.0.7)
set(OPENSSL_TARGET_PLATFORM VC-WIN64A)
set(OPENSSL_CONFIGURE_OPTIONS no-shared no-tests)

FetchContent_Declare(
    openssl-cmake
    URL https://github.com/jimmy-park/openssl-cmake/archive/0.5.0.tar.gz
)

# This line must be preceded before find_package(OpenSSL)
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
    URL https://github.com/jimmy-park/openssl-cmake/archive/0.5.0.tar.gz
    OPTIONS
    "OPENSSL_TARGET_VERSION 3.0.7"
    "OPENSSL_TARGET_PLATFORM VC-WIN64A"
    "OPENSSL_CONFIGURE_OPTIONS no-shared\\\\;no-tests"
)
```
