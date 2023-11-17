# Python Runtime Builder
This project uses pyenv plus a set of customization scripts to build a portable python runtime artifact. This artifact can then be used in any compatible system/container without needing to install the system python, or it can run alongside the system python without interference.

As an example, this repo is setup to build a python runtime for REST services using FastAPI. It also includes an example of installing ansible in a venv as part of the runtime.

## Features

### Versioning
By default the makefile will look for git tags (`v*`) and pick the latest one to use as the version. This can be overridden with the `PACKAGE_VERSION` variable.

### Manifest
A JSON manifest is created each time the runtime is built, containing the python version, list of python packages/versions, and the overall package version.

### Multi-Arch Builds
AMD64/x86_64 and ARM64/aarch64 are both supported. The makefile targets will default to building for your local/native architecture. Qemu/binfmt are required for building an architecture that is not your native CPU;. If you are using Docker Desktop it should be already configured for you, or on Linux/WSL install binfmt-support and qemu-static-user packages (those are the debian names, adjust to your distro).

### Build Caching
The build script will attempt to use cached artifacts to speed up parts of the build: python - the first time python is built from source, the result is saved; pip - the pip download cache is saved.
The cache artifacts are stored in the `ARTIFACT_DIR` to be reused. They can also be saved in a remote cache; you will need to provide a web server that supports webdav (GET and PUT). A simple way to do this is to use https://github.com/cseelye/nginx-server combined with the example config file [here](remote_cache/nginx-default.conf).

## Customizing
The easiest way to start is to create a `Makefile.vars` file to override the config variables that you want to set. The main Makefile will import this file and use any values it finds there. Then create any requirements files/scripts you need to add additional content to the runtime.

### Config Variables
| Variable | Description |
| -------- | ----------- |
| `PRT_ROOT` | The directory the runtime is built/installed/run in. This should be set to the final directory you want the runtime to be installed to in your container/system. <br />Default: `/prt` |
| `PYTHON_VERSION` | The version of python to use for the runtime. <br />Default: `3.11.5` |
| `ARTIFACT_DIR` | The directory to put the packages and other artifacts when they are built. <br />Default: `out` |
| `PACKAGE_PREFIX` | Prefix to use for package names (tar and deb). <br />Default: `prt` |
| `PACKAGE_DESC` | Description of the package, used for DEB packages. |
| `PACKAGE_MAINTAINER` | Name of the maintainer, used for DEB packages. |


## Usage
The default target (running `make` by itself) will print out the value of all of the variables. To build the runtime, use one of the targets for the artifact you want (eg `make runtime` or `make deb`), or `make all` to build everything. The simple targets (`make runtime`) will detect the CPU architecture and run the native version of the target. If you want to build for another architecture you can call the explicit version of the target (`make runtime-arm`).

The makefile has a `help` target that will print usage:
```
Each target will run the local/native version automatically, or you can run the explicit AMD64 or ARM64 variant

Build the runtime:
  make runtime                      Build the runtime and package it as a tarball in the output directory
  make runtime-x86
  make runtime-arm
  make deb                          Build the runtime and package it as a deb in the output directory
  make deb-x86
  make deb-arm
  make builder-image-x86            Build the docker image used to build the runtime
  make builder-image-arm

NO_PACKAGE_CACHE=1 can be used to build without using cached pip packages
NO_CACHE=1 can be used to build without using any cached python/pip packages

Testing:
  make test                         Install the tar package in a fresh container and test it
  make test-x86
  make test-arm
  make test-dev                     Install the dev tar package in a fresh container and test it
  make test-dev-x86
  make test-dev-arm
  make test-deb                     Install the debian package in a fresh container and test it
  make test-deb-x86
  make test-deb-arm
  make test-deb-dev                 Install the dev debian package in a fresh container and test it
  make test-deb-dev-x86
  make test-deb-dev-arm

  make test-all                     Run the tests for all the variations

  make run                          Install the package in a fresh container and get an interactive prompt
  make run-x86
  make run-arm
  make run-dev                      Install the dev package in a fresh container and get an interactive prompt
  make run-dev-x86
  make run-dev-arm

Cleanup:
  make clean                        Delete the runtime package
  make clobber                      Delete the runtime package, cache files, and docker images

Misc:
  make upload-cache                 Upload the cache files to the cache server, replacing what is there.
```
