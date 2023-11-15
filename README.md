# Custom Python Runtime
This project uses pyenv plus a set of customization scripts to build a portable python runtime artifact. This artifact can then be used in any compatible system/container without needing to install the system python, or it can run alongside the system python without interference.

The python runtime is built inside the container in the /prt directory. This can be changed with the PRT_ROOT makefile variable. The runtime must be installed into your system/container in the same path to function properly.

The makefile has a `help` target that will print usage:
```
Build the runtime:
  make runtime                          Build the runtime and package it as a tarball in the output directory
  make deb                              Build the runtime and package it as a deb in the output directory
  make builder-image                    Build the docker image used to build the runtime
  make runtime-arm                      Build the runtime (arm64) and package it as a tarball in the output directory
  make deb-arm                          Build the runtime (arm64) and package it as a deb in the output directory
  make builder-image-arm                Build the docker image (arm64) used to build the runtime
NO_PACKAGE_CACHE=1 can be used to build without using cached pip packages
NO_CACHE=1 can be used to build without using any cached python/pip packages

Testing:
  make test                             Install the package in a fresh container and test it
  make test-dev                         Install the dev package in a fresh container and test it
  make test-arm                         Install the ARM64 package in a fresh container and test it
  make test-arm-dev                     Install the ARM64 dev package in a fresh container and test it
  make test-all                          Run the tests for all the variations
  make run                              Install the package in a fresh container and get an interactive prompt
  make run-dev                          Install the dev package in a fresh container and get an interactive prompt

Cleanup:
  make clean                            Delete the runtime package
  make clobber                          Delete the runtime package, cache files, and docker images

Misc:
  make upload-cache                     Upload the cache files to the cache server, replacing what is there.

```
