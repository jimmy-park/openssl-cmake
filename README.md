# openssl-cmake

[![CI](https://github.com/jimmy-park/openssl-cmake/actions/workflows/ci.yaml/badge.svg)](https://github.com/jimmy-park/openssl-cmake/actions/workflows/ci.yaml)

Build and integrate OpenSSL from CMake with fast parallel builds.

## Features

- Detects common target platforms automatically (`Linux`, `macOS`, `Windows`, `Android`, `iOS`, and more)
- Supports OpenSSL `1.1.1` and the latest OpenSSL releases
- Works with existing `find_package(OpenSSL)` integration and `OpenSSL::...` targets
- Builds in parallel when supported
- Speeds up rebuilds with [ccache](https://github.com/ccache/ccache)
- Reuses downloaded source archives and skips unnecessary reconfiguration

## Usage

Use `Build` to try this repository directly, or `Integration` to add it to another CMake project.

### Build

The fastest way to try this repository is to build it with one of the included presets. Replace `<preset>` with a preset available on your current host platform.
OpenSSL self tests are optional. Configure with `-DOPENSSL_TEST=ON` and then run `ctest --preset <preset>`.

```sh
cmake --list-presets all                    # List available presets
cmake --preset <preset>                     # Configure
cmake --build --preset <preset>             # Build
cmake --build --preset <preset> -t install  # Install
```

### Integration

```cmake
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
> Call `FetchContent_MakeAvailable(openssl-cmake)` before any dependency calls `find_package(OpenSSL)`.
> If another library links OpenSSL through `OPENSSL_LIBRARIES` instead of `OpenSSL::SSL`, `add_dependencies()` may help enforce the correct build order.

#### Using [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake)

```cmake
CPMAddPackage(
    NAME openssl-cmake
    URL https://github.com/jimmy-park/openssl-cmake/archive/main.tar.gz
    OPTIONS
    "OPENSSL_CONFIGURE_OPTIONS option1\\\\;option2"
)
```

CPM.cmake requires double-escaping for semicolon-separated lists in `OPTIONS`.

## Prerequisites

### Requirements

- CMake 3.25+
- [OpenSSL build prerequisites](https://github.com/openssl/openssl/blob/master/INSTALL.md#prerequisites)
  - Make implementation
  - Perl 5
  - ANSI C compiler
  - NASM (Windows only)
- ccache (optional)

### Linux

Install CMake from the [official website](https://cmake.org/download/) or [Snapcraft](https://snapcraft.io/docs/installing-snapd), then install the required build tools.

```sh
# Debian
sudo snap install cmake --classic
sudo apt-get install -y build-essential perl ninja-build ccache
```

### macOS

Install the required packages with [Homebrew](https://brew.sh/).

```sh
brew install cmake perl ninja ccache
xcode-select --install
```

### Windows

Install the required packages with [Chocolatey](https://chocolatey.org/install).

```powershell
# PowerShell (run as administrator)
choco install -y cmake jom strawberryperl nasm ccache --installargs 'ADD_CMAKE_TO_PATH=System'

# Add "C:\Program Files\NASM" to the PATH environment variable,
# or run the following command.
[Environment]::SetEnvironmentVariable("PATH", "$ENV:PATH;C:\Program Files\NASM", "USER")
```

## CMake Options

| Option                      | Type   | Default                 | Description                                          |
| --------------------------- | ------ | ----------------------- | ---------------------------------------------------- |
| `OPENSSL_BUILD_OPTIONS`     | list   | `(undefined)`           | Pass extra `make`-compatible build options           |
| `OPENSSL_BUILD_TARGET`      | string | `build_libs`            | Select the Makefile target to build                  |
| `OPENSSL_BUILD_VERBOSE`     | bool   | `OFF`                   | Show verbose output during the build                 |
| `OPENSSL_CONFIGURE_OPTIONS` | list   | `(undefined)`           | Pass extra options to OpenSSL `Configure`            |
| `OPENSSL_CONFIGURE_VERBOSE` | bool   | `OFF`                   | Show verbose output during configuration             |
| `OPENSSL_ENABLE_PARALLEL`   | bool   | `ON`                    | Build and test in parallel when supported            |
| `OPENSSL_INSTALL`           | bool   | `OFF`                   | Install OpenSSL components                           |
| `OPENSSL_INSTALL_CERT`      | bool   | `OFF`                   | Install `cert.pem` into the `openssldir` directory   |
| `OPENSSL_INSTALL_TARGET`    | string | `install_dev`           | Select the Makefile target to install                |
| `OPENSSL_PATCH`             | list   | `(undefined)`           | Apply patch files to the OpenSSL source tree         |
| `OPENSSL_SOURCE`            | path   | `(undefined)`           | Specify the location of OpenSSL source (URL or path) |
| `OPENSSL_TARGET_PLATFORM`   | string | `(undefined)`           | Set the OpenSSL `Configure` target explicitly        |
| `OPENSSL_TARGET_VERSION`    | string | `openssl-cmake version` | Set the exact OpenSSL release to fetch               |
| `OPENSSL_TEST`              | bool   | `OFF`                   | Build and run the OpenSSL self tests                 |
| `OPENSSL_USE_CCACHE`        | bool   | `ON`                    | Enable `ccache` when it is available                 |

- `OPENSSL_CONFIGURE_OPTIONS`: `no-shared` is added when `BUILD_SHARED_LIBS` is `OFF`.
- `OPENSSL_CONFIGURE_OPTIONS`: `no-tests` is added when `OPENSSL_TEST` is `OFF`.
- `OPENSSL_PATCH`: Patch files must use `LF` line endings because the OpenSSL source tree uses `LF`.
- `OPENSSL_SOURCE`: This can point to either a local source tree or a downloadable archive.
- `OPENSSL_TARGET_PLATFORM`: This is detected automatically unless you set it explicitly.
- `OPENSSL_TARGET_VERSION`: If not set, `openssl-cmake` uses its own project version by default.
- `OPENSSL_USE_CCACHE`: If you change this option, run a fresh configure or remove `CMakeCache.txt`.
- `OPENSSL_USE_CCACHE`: On MSVC, this option also removes `/Zi` and `/Fd`.
