# Custom Python Runtime
This project uses pyenv plus a set of customization scripts to build a portable python runtime artifact. This artifact can then be used in any compatible system/container without needing to install the system python, or it can run alongside the system python without interference.

The python runtime is built inside the container in the /prt directory. This can be changed with the PRT_ROOT makefile variable. The runtime must be installed into your system/container in the same path to function properly.
