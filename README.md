# openssl-cmake

[![CI](https://github.com/jimmy-park/openssl-cmake/actions/workflows/ci.yaml/badge.svg)](https://github.com/jimmy-park/openssl-cmake/actions/workflows/ci.yaml)

Build OpenSSL in parallel within CMake

## Features

- Support OpenSSL versions from `1.1.1` to the latest `3.6.x`
- Detect the target platform (`Linux`, `macOS`, `Windows`, `Android`, `iOS`, and more)
- Download the source code only once (thanks [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake)!)
- Don't reconfigure if same options are used
- Automatically use the maximum number of processors
- Reduce rebuild time using [ccache](https://github.com/ccache/ccache)
- Override the [`FindOpenSSL`](https://cmake.org/cmake/help/latest/module/FindOpenSSL.html) CMake module (no need to change existing CMake code)

## CMake Options

| Option                      | Type   | Default       | Description                                          |
| --------------------------- | ------ | ------------- | ---------------------------------------------------- |
| `OPENSSL_BUILD_OPTIONS`     | list   | `(undefined)` | `make`-compatible options                            |
| `OPENSSL_BUILD_TARGET`      | string | `build_libs`  | Makefile target for build                            |
| `OPENSSL_BUILD_VERBOSE`     | bool   | `OFF`         | Enable verbose output from build                     |
| `OPENSSL_CONFIGURE_OPTIONS` | list   | `(undefined)` | Use OpenSSL's Configure options                      |
| `OPENSSL_CONFIGURE_VERBOSE` | bool   | `OFF`         | Enable verbose output from configuration             |
| `OPENSSL_ENABLE_PARALLEL`   | bool   | `ON`          | Build and test in parallel if possible               |
| `OPENSSL_INSTALL`           | bool   | `OFF`         | Install OpenSSL components                           |
| `OPENSSL_INSTALL_CERT`      | bool   | `OFF`         | Install `cert.pem` to the `openssldir` directory     |
| `OPENSSL_INSTALL_TARGET`    | string | `install_dev` | Makefile target for install                          |
| `OPENSSL_PATCH`             | list   | `(undefined)` | Apply patches to OpenSSL source                      |
| `OPENSSL_SOURCE`            | path   | `(undefined)` | Specify the location of OpenSSL source (URL or path) |
| `OPENSSL_TARGET_PLATFORM`   | string | `(undefined)` | Use OpenSSL's Configure target (see below)           |
| `OPENSSL_TARGET_VERSION`    | string | `3.6.x`       | Use the latest OpenSSL version by default            |
| `OPENSSL_TEST`              | bool   | `OFF`         | Enable testing and build OpenSSL self tests          |
| `OPENSSL_USE_CCACHE`        | bool   | `ON`          | Use ccache if available                              |

> [!IMPORTANT]
>
> - `OPENSSL_PATCH`
>   - Since OpenSSL source is distributed with `LF`, patch files also should be `LF`
> - `OPENSSL_USE_CCACHE`
>   - Whenever you change this option, perform a fresh configuration (or just delete `CMakeCache.txt`)
>   - This option will remove `/Zi /Fd` on MSVC

> [!NOTE]
>
> - `OPENSSL_CONFIGURE_OPTIONS`
>   - `no-shared` is added when `BUILD_SHARED_LIBS` is `OFF`
>   - `no-tests` is added when `OPENSSL_TEST` is `OFF`
> - `OPENSSL_TARGET_PLATFORM`
>   - If this option is empty, the target platform will be detected
>   - If `openssl-cmake` fails to detect, you need to set this option explicitly

> [!TIP]
>
> - `OPENSSL_INSTALL`
>   - To change the installation path, add `--prefix=<path>` to `OPENSSL_CONFIGURE_OPTIONS`
> - `OPENSSL_INSTALL_CERT`
>   - The CA certs will be downloaded from <https://curl.se/docs/caextract.html>
> - `OPENSSL_SOURCE`
>   - You can download OpenSSL source from the internet or use the local OpenSSL source
>   - If this option is empty or invalid, OpenSSL source will be downloaded from the official website

## Prerequisites

### Requirements

- CMake 3.25+
- OpenSSL build tools [Link](https://github.com/openssl/openssl/blob/master/INSTALL.md#prerequisites)
  - Make implementation
  - Perl 5
  - ANSI C compiler
  - NASM (Windows only)
- ccache (optional)

### Linux

Install CMake from [official website](https://cmake.org/download/) or [Snapcraft](https://snapcraft.io/docs/installing-snapd)

```sh
# Debian
sudo snap install cmake --classic
sudo apt-get install -y build-essential perl ninja-build ccache
```

### macOS

Install packages from [Homebrew](https://brew.sh/)

```sh
brew install cmake perl ninja ccache
xcode-select --install
```

### Windows

Install packages from [Chocolatey](https://chocolatey.org/install)

```sh
# Powershell (run as administrator)
choco install -y cmake jom strawberryperl nasm ccache --installargs 'ADD_CMAKE_TO_PATH=System'

# Append "C:\Program Files\NASM" to the PATH environment variable
# or run this code
[Environment]::SetEnvironmentVariable("PATH", "$ENV:PATH;C:\Program Files\NASM", "USER")
```

## Usage

### Build

```sh
cmake --list-presets all                    # List all CMake presets
cmake --preset windows                      # Configure
cmake --build --preset windows              # Build
ctest --preset windows                      # Test
cmake --build --preset windows -t install   # Install
```

### Integration

```CMake
FetchContent_Declare(
    openssl-cmake
    URL https://github.com/jimmy-park/openssl-cmake/archive/main.tar.gz
)
FetchContent_MakeAvailable(openssl-cmake)

add_executable(main main.cpp)
target_link_libraries(main PRIVATE
    OpenSSL::SSL
    OpenSSL::Crypto
    OpenSSL::applink
)
```

> [!IMPORTANT]
>
> - `FetchContent_MakeAvailable(openssl-cmake)` must be preceded before `find_package(OpenSSL)`
> - If some libraries link OpenSSL using `OPENSSL_LIBRARIES` variable rather than `OpenSSL::SSL` target, `add_dependencies()` may help change the build order

#### Using [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake)

```CMake
CPMAddPackage(
    NAME openssl-cmake
    URL https://github.com/jimmy-park/openssl-cmake/archive/main.tar.gz
    OPTIONS
    "OPENSSL_CONFIGURE_OPTIONS option1\\\\;option2"
)
```

> [!TIP]
> For some reason, CPM requires double-escaping for semicolon-separated lists.

## Benchmarks

| Configuration               |  Time |      Speed |
| --------------------------- | ----: | ---------: |
| Sequential                  | 168 s |     1.00 x |
| Sequential w/ ccache (cold) | 460 s |     0.37 x |
| Sequential w/ ccache (warm) | 111 s |     1.51 x |
| Parallel                    |  34 s |     4.94 x |
| Parallel w/ ccache (cold)   |  78 s |     2.15 x |
| Parallel w/ ccache (warm)   |  21 s | **8.00 x** |

- **OS** : Windows 10 22H2
- **CPU** : AMD Ryzen 5 3600 6-Core Processor 3.60 GHz
- **RAM** : 16 GB
- **Storage** : Samsung SSD 860 EVO
- **Compiler** : MSVC 19.36
- **Configuration**
  - OpenSSL 3.1.1 (`VC-WIN64A`, `no-tests`, `no-asm`, `no-makedepend`, `no-shared`)
  - ccache 4.8.1 (default options)

> [!TIP]
> There are [benchmark workflows](https://github.com/jimmy-park/openssl-cmake/actions/workflows/ccache.yaml)
